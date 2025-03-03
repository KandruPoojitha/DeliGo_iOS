import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseDatabase

struct DocumentUploadView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var governmentID: PhotosPickerItem?
    @State private var governmentIDImage: Image?
    @State private var driversLicense: PhotosPickerItem?
    @State private var driversLicenseImage: Image?
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Upload Required Documents")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Government ID Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Government ID Proof")
                        .font(.headline)
                    
                    if let governmentIDImage {
                        governmentIDImage
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    } else {
                        PhotosPicker(selection: $governmentID, matching: .images) {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.badge.plus")
                                    .font(.system(size: 30))
                                    .foregroundColor(Color(hex: "F4A261"))
                                Text("Upload Government ID")
                                    .foregroundColor(Color(hex: "F4A261"))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(Color(hex: "F4A261").opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                
                // Driver's License Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("License")
                        .font(.headline)
                    
                    if let driversLicenseImage {
                        driversLicenseImage
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    } else {
                        PhotosPicker(selection: $driversLicense, matching: .images) {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.badge.plus")
                                    .font(.system(size: 30))
                                    .foregroundColor(Color(hex: "F4A261"))
                                Text("Upload Driver's License")
                                    .foregroundColor(Color(hex: "F4A261"))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(Color(hex: "F4A261").opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                
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
                .background(Color(hex: "F4A261"))
                .cornerRadius(12)
                .disabled(isUploading || governmentID == nil || driversLicense == nil)
                .opacity((governmentID == nil || driversLicense == nil) ? 0.6 : 1)
            }
            .padding()
        }
        .onChange(of: governmentID) { _ in
            Task {
                await loadImage(from: governmentID, into: $governmentIDImage)
            }
        }
        .onChange(of: driversLicense) { _ in
            Task {
                await loadImage(from: driversLicense, into: $driversLicenseImage)
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
            print("Error loading image: \(error)")
        }
    }
    
    private func submitDocuments() {
        guard let userId = authViewModel.currentUserId else { return }
        isUploading = true
        
        Task {
            do {
                // Upload government ID
                if let governmentID = governmentID,
                   let governmentIDData = try await governmentID.loadTransferable(type: Data.self) {
                    let govIDRef = Storage.storage().reference().child("restaurants/\(userId)/government_id.jpg")
                    _ = try await govIDRef.putDataAsync(governmentIDData)
                    let govIDURL = try await govIDRef.downloadURL()
                    
                    // Upload driver's license
                    if let driversLicense = driversLicense,
                       let driversLicenseData = try await driversLicense.loadTransferable(type: Data.self) {
                        let licenseRef = Storage.storage().reference().child("restaurants/\(userId)/drivers_license.jpg")
                        _ = try await licenseRef.putDataAsync(driversLicenseData)
                        let licenseURL = try await licenseRef.downloadURL()
                        
                        // Update user document status in database
                        let db = Database.database().reference()
                        let documentsData: [String: Any] = [
                            "governmentID": govIDURL.absoluteString,
                            "driversLicense": licenseURL.absoluteString,
                            "status": "pending",
                            "submittedAt": ServerValue.timestamp()
                        ]
                        
                        try await db.child("restaurants/\(userId)/documents").setValue(documentsData)
                        
                        // Update auth view model
                        await MainActor.run {
                            authViewModel.documentStatus = .pending
                            isUploading = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isUploading = false
                }
            }
        }
    }
}

#Preview {
    DocumentUploadView(authViewModel: AuthViewModel())
} 
