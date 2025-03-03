import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseDatabase

struct RestaurantDocumentUploadView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    // Document Selection States
    @State private var restaurantProof: PhotosPickerItem?
    @State private var restaurantProofImage: Image?
    @State private var ownerID: PhotosPickerItem?
    @State private var ownerIDImage: Image?
    
    // Business Hours
    @State private var openingTime = Date()
    @State private var closingTime = Date()
    
    // Upload States
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var isSubmitEnabled: Bool {
        restaurantProof != nil && ownerID != nil
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title
                Text("Restaurant Verification")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.vertical)
                
                // Restaurant License Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Restaurant Registration/License")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    if let restaurantProofImage {
                        restaurantProofImage
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 150)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    } else {
                        PhotosPicker(selection: $restaurantProof, matching: .images) {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.badge.plus")
                                    .font(.system(size: 30))
                                    .foregroundColor(Color(hex: "F4A261"))
                                Text("Upload Restaurant Proof")
                                    .foregroundColor(Color(hex: "F4A261"))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .background(Color(hex: "F4A261").opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.bottom)
                
                // Owner ID Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Owner's Government ID")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    if let ownerIDImage {
                        ownerIDImage
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 150)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    } else {
                        PhotosPicker(selection: $ownerID, matching: .images) {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.badge.plus")
                                    .font(.system(size: 30))
                                    .foregroundColor(Color(hex: "F4A261"))
                                Text("Upload Owner's ID")
                                    .foregroundColor(Color(hex: "F4A261"))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .background(Color(hex: "F4A261").opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.bottom)
                
                // Business Hours Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Business Hours")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Opening Time")
                            .foregroundColor(.gray)
                        DatePicker("", selection: $openingTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Closing Time")
                            .foregroundColor(.gray)
                        DatePicker("", selection: $closingTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
                .padding(.bottom)
                
                // Submit Button
                Button(action: submitDocuments) {
                    if isUploading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Submit Documents")
                            .fontWeight(.medium)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSubmitEnabled ? Color(hex: "F4A261") : Color(hex: "F4A261").opacity(0.6))
                .cornerRadius(12)
                .disabled(!isSubmitEnabled || isUploading)
            }
            .padding()
        }
        .onChange(of: restaurantProof) { _ in
            Task {
                await loadImage(from: restaurantProof, into: $restaurantProofImage)
            }
        }
        .onChange(of: ownerID) { _ in
            Task {
                await loadImage(from: ownerID, into: $ownerIDImage)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadImage(from item: PhotosPickerItem?, into binding: Binding<Image?>) async {
        guard let item = item else { return }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                binding.wrappedValue = Image(uiImage: uiImage)
            }
        } catch {
            await handleError("Error loading image: \(error.localizedDescription)")
        }
    }
    
    private func submitDocuments() {
        guard let userId = authViewModel.currentUserId else { return }
        isUploading = true
        
        // Save business hours first
        let hours = [
            "opening": formatTime(openingTime),
            "closing": formatTime(closingTime)
        ]
        
        let db = Database.database().reference()
        db.child("restaurants").child(userId).child("hours").setValue(hours) { error, _ in
            if let error = error {
                handleError("Failed to save business hours: \(error.localizedDescription)")
                return
            }
            
            // Upload restaurant proof
            uploadDocument(restaurantProof, type: "restaurant_proof") {
                // Upload owner ID after restaurant proof
                uploadDocument(ownerID, type: "owner_id") {
                    finalizeUpload()
                }
            }
        }
    }
    
    private func uploadDocument(_ item: PhotosPickerItem?, type: String, completion: @escaping () -> Void) {
        guard let item = item,
              let userId = authViewModel.currentUserId else {
            handleError("Missing document or user ID")
            return
        }
        
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image data"])
                }
                
                let filename = "\(type)_\(Int(Date().timeIntervalSince1970)).jpg"
                let storageRef = Storage.storage().reference()
                    .child("restaurant_documents")
                    .child(userId)
                    .child(filename)
                
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                
                _ = try await storageRef.putDataAsync(data, metadata: metadata)
                let downloadURL = try await storageRef.downloadURL()
                
                let fileData: [String: Any] = [
                    "url": downloadURL.absoluteString,
                    "uploadTime": ServerValue.timestamp()
                ]
                
                let db = Database.database().reference()
                try await db.child("restaurants")
                    .child(userId)
                    .child("documents")
                    .child("files")
                    .child(type)
                    .setValue(fileData)
                
                await MainActor.run {
                    completion()
                }
            } catch {
                await handleError("Failed to upload \(type): \(error.localizedDescription)")
            }
        }
    }
    
    private func finalizeUpload() {
        guard let userId = authViewModel.currentUserId else { return }
        
        let updates: [String: Any] = [
            "documentsSubmitted": true,
            "documents/status": "pending_review"
        ]
        
        let db = Database.database().reference()
        db.child("restaurants").child(userId).updateChildValues(updates) { error, _ in
            if let error = error {
                handleError("Failed to finalize upload: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                authViewModel.documentStatus = .pending
                isUploading = false
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func handleError(_ message: String) {
        DispatchQueue.main.async {
            errorMessage = message
            showError = true
            isUploading = false
        }
    }
}

#Preview {
    RestaurantDocumentUploadView(authViewModel: AuthViewModel())
}
