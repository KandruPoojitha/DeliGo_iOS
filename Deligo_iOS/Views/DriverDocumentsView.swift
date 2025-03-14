import SwiftUI
import FirebaseStorage
import FirebaseDatabase

struct DriverDocumentsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var governmentIDImage: UIImage?
    @State private var driverLicenseImage: UIImage?
    @State private var showingGovernmentIDPicker = false
    @State private var showingDriverLicensePicker = false
    @State private var isUploading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var documentStatus: String = "not_submitted"
    
    // Working Hours State
    @State private var startHour = 9
    @State private var startMinute = 0
    @State private var endHour = 17
    @State private var endMinute = 0
    
    private let storage = Storage.storage().reference()
    private let database = Database.database().reference()
    
    private let hours = Array(0...23)
    private let minutes = Array(0...59)
    
    var body: some View {
        Group {
            if documentStatus == "pending_review" {
                DocumentsUnderReviewView(authViewModel: authViewModel)
            } else {
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
                            
                            if let image = governmentIDImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                    .cornerRadius(12)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 200)
                                    .cornerRadius(12)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 30))
                                            .foregroundColor(.gray)
                                    )
                            }
                            
                            Button(action: {
                                showingGovernmentIDPicker = true
                            }) {
                                Text("Upload Government ID")
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(hex: "F4A261"))
                                    .cornerRadius(25)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Driver's License Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Driver's License")
                                .font(.headline)
                            
                            if let image = driverLicenseImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                    .cornerRadius(12)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 200)
                                    .cornerRadius(12)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 30))
                                            .foregroundColor(.gray)
                                    )
                            }
                            
                            Button(action: {
                                showingDriverLicensePicker = true
                            }) {
                                Text("Upload Driver's License")
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(hex: "F4A261"))
                                    .cornerRadius(25)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Working Hours Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Working Hours")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            // Start Time
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Start")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                                
                                HStack {
                                    Picker("Hour", selection: $startHour) {
                                        ForEach(hours, id: \.self) { hour in
                                            Text("\(String(format: "%02d", hour))")
                                                .tag(hour)
                                        }
                                    }
                                    .pickerStyle(WheelPickerStyle())
                                    .frame(width: 100)
                                    .clipped()
                                    
                                    Text(":")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                    
                                    Picker("Minute", selection: $startMinute) {
                                        ForEach(minutes, id: \.self) { minute in
                                            Text("\(String(format: "%02d", minute))")
                                                .tag(minute)
                                        }
                                    }
                                    .pickerStyle(WheelPickerStyle())
                                    .frame(width: 100)
                                    .clipped()
                                }
                            }
                            
                            // End Time
                            VStack(alignment: .leading, spacing: 8) {
                                Text("End")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                                
                                HStack {
                                    Picker("Hour", selection: $endHour) {
                                        ForEach(hours, id: \.self) { hour in
                                            Text("\(String(format: "%02d", hour))")
                                                .tag(hour)
                                        }
                                    }
                                    .pickerStyle(WheelPickerStyle())
                                    .frame(width: 100)
                                    .clipped()
                                    
                                    Text(":")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                    
                                    Picker("Minute", selection: $endMinute) {
                                        ForEach(minutes, id: \.self) { minute in
                                            Text("\(String(format: "%02d", minute))")
                                                .tag(minute)
                                        }
                                    }
                                    .pickerStyle(WheelPickerStyle())
                                    .frame(width: 100)
                                    .clipped()
                                }
                            }
                        }
                        .padding(.vertical)
                        
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
                        .disabled(isUploading || governmentIDImage == nil || driverLicenseImage == nil)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            (governmentIDImage == nil || driverLicenseImage == nil || isUploading) ?
                            Color(hex: "F4A261").opacity(0.6) :
                            Color(hex: "F4A261")
                        )
                        .cornerRadius(25)
                        .padding(.horizontal)
                    }
                }
                .sheet(isPresented: $showingGovernmentIDPicker) {
                    ImagePicker(image: $governmentIDImage)
                }
                .sheet(isPresented: $showingDriverLicensePicker) {
                    ImagePicker(image: $driverLicenseImage)
                }
                .alert("Document Submission", isPresented: $showAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(alertMessage)
                }
            }
        }
        .onAppear {
            checkDocumentStatus()
        }
    }
    
    private func checkDocumentStatus() {
        guard let userId = authViewModel.currentUserId else { return }
        
        database.child("drivers").child(userId).child("documents").child("status")
            .observeSingleEvent(of: .value) { snapshot in
                if let status = snapshot.value as? String {
                    self.documentStatus = status
                }
            }
    }
    
    private func submitDocuments() {
        guard let userId = authViewModel.currentUserId,
              let governmentID = governmentIDImage,
              let driverLicense = driverLicenseImage else { return }
        
        isUploading = true
        
        let group = DispatchGroup()
        var uploadedUrls: [String: String] = [:]
        var uploadError: Error?
        let timestamp = ServerValue.timestamp()
        
        // Format working hours as separate "HH:MM" strings
        let startTimeString = String(format: "%02d:%02d", startHour, startMinute)
        let endTimeString = String(format: "%02d:%02d", endHour, endMinute)
        
        // Upload Government ID
        group.enter()
        uploadImage(governmentID, path: "drivers/\(userId)/govt_id.jpg") { result in
            switch result {
            case .success(let url):
                uploadedUrls["govt_id"] = url
            case .failure(let error):
                uploadError = error
            }
            group.leave()
        }
        
        // Upload Driver's License
        group.enter()
        uploadImage(driverLicense, path: "drivers/\(userId)/license.jpg") { result in
            switch result {
            case .success(let url):
                uploadedUrls["license"] = url
            case .failure(let error):
                uploadError = error
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            if let error = uploadError {
                alertMessage = "Error uploading documents: \(error.localizedDescription)"
                showAlert = true
                isUploading = false
                return
            }
            
            // Update database with document URLs, status, and working hours
            let documentsData: [String: Any] = [
                "documents": [
                    "govt_id": [
                        "uploadTime": timestamp,
                        "url": uploadedUrls["govt_id"] ?? ""
                    ],
                    "license": [
                        "uploadTime": timestamp,
                        "url": uploadedUrls["license"] ?? ""
                    ],
                    "status": "pending_review",
                    "updatedAt": timestamp
                ],
                "hours": [
                    "start": startTimeString,
                    "end": endTimeString
                ],
                "documentsSubmitted": true,
                "createdAt": timestamp,
                "updatedAt": timestamp
            ]
            
            database.child("drivers").child(userId)
                .updateChildValues(documentsData) { error, _ in
                    isUploading = false
                    
                    if let error = error {
                        alertMessage = "Error saving document information: \(error.localizedDescription)"
                    } else {
                        alertMessage = "Documents submitted successfully! They are now pending review."
                        documentStatus = "pending_review"
                    }
                    showAlert = true
                }
        }
    }
    
    private func uploadImage(_ image: UIImage, path: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.6) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])))
            return
        }
        
        let imageRef = storage.child(path)
        imageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            imageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                } else if let urlString = url?.absoluteString {
                    completion(.success(urlString))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                }
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
} 