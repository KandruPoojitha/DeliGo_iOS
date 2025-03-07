import SwiftUI
import FirebaseStorage
import FirebaseDatabase

struct RestaurantDocumentsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var restaurantLicenseImage: UIImage?
    @State private var ownerIDImage: UIImage?
    @State private var showingRestaurantLicensePicker = false
    @State private var showingOwnerIDPicker = false
    @State private var isUploading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var documentStatus: String = "not_submitted"
    
    private let storage = Storage.storage().reference()
    private let database = Database.database().reference()
    
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
                        
                        // Restaurant License Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Restaurant License")
                                .font(.headline)
                            
                            if let image = restaurantLicenseImage {
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
                                showingRestaurantLicensePicker = true
                            }) {
                                Text("Upload Restaurant License")
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(hex: "F4A261"))
                                    .cornerRadius(25)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Owner ID Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Owner's ID")
                                .font(.headline)
                            
                            if let image = ownerIDImage {
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
                                showingOwnerIDPicker = true
                            }) {
                                Text("Upload Owner's ID")
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(hex: "F4A261"))
                                    .cornerRadius(25)
                            }
                        }
                        .padding(.horizontal)
                        
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
                        .disabled(isUploading || restaurantLicenseImage == nil || ownerIDImage == nil)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            (restaurantLicenseImage == nil || ownerIDImage == nil || isUploading) ?
                            Color(hex: "F4A261").opacity(0.6) :
                            Color(hex: "F4A261")
                        )
                        .cornerRadius(25)
                        .padding(.horizontal)
                    }
                }
                .sheet(isPresented: $showingRestaurantLicensePicker) {
                    ImagePicker(image: $restaurantLicenseImage)
                }
                .sheet(isPresented: $showingOwnerIDPicker) {
                    ImagePicker(image: $ownerIDImage)
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
        
        database.child("restaurants").child(userId).child("documents").child("status")
            .observeSingleEvent(of: .value) { snapshot in
                if let status = snapshot.value as? String {
                    self.documentStatus = status
                }
            }
    }
    
    private func submitDocuments() {
        guard let userId = authViewModel.currentUserId,
              let restaurantLicense = restaurantLicenseImage,
              let ownerID = ownerIDImage else { return }
        
        isUploading = true
        
        let group = DispatchGroup()
        var uploadedUrls: [String: String] = [:]
        var uploadError: Error?
        let timestamp = ServerValue.timestamp()
        
        // Upload Restaurant License
        group.enter()
        uploadImage(restaurantLicense, path: "restaurants/\(userId)/restaurant_proof.jpg") { result in
            switch result {
            case .success(let url):
                uploadedUrls["restaurant_proof"] = url
            case .failure(let error):
                uploadError = error
            }
            group.leave()
        }
        
        // Upload Owner ID
        group.enter()
        uploadImage(ownerID, path: "restaurants/\(userId)/owner_id.jpg") { result in
            switch result {
            case .success(let url):
                uploadedUrls["owner_id"] = url
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
            
            // Update database with document URLs and status
            let documentsData: [String: Any] = [
                "documents": [
                    "restaurant_proof": [
                        "uploadTime": timestamp,
                        "url": uploadedUrls["restaurant_proof"] ?? ""
                    ],
                    "owner_id": [
                        "uploadTime": timestamp,
                        "url": uploadedUrls["owner_id"] ?? ""
                    ],
                    "status": "pending_review",
                    "updatedAt": timestamp
                ],
                "documentsSubmitted": true,
                "createdAt": timestamp,
                "updatedAt": timestamp
            ]
            
            database.child("restaurants").child(userId)
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