import SwiftUI
import FirebaseStorage
import FirebaseDatabase
import GooglePlaces

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
    
    // Store Info Fields
    @State private var address = ""
    @State private var minPrice = 5.0
    @State private var maxPrice = 25.0
    @State private var openingTime = Date()
    @State private var closingTime = Date()
    
    // Address Suggestion Fields
    @State private var searchResults: [GMSAutocompletePrediction] = []
    @State private var showingAddressSuggestions = false
    private let placesClient = GMSPlacesClient.shared()
    
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
                        
                        // Restaurant Address Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Restaurant Address")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 0) {
                                TextField("Enter your restaurant address", text: $address)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(12)
                                    .onChange(of: address) { oldValue, newValue in
                                        if !newValue.isEmpty {
                                            searchAddress(newValue)
                                            showingAddressSuggestions = true
                                        } else {
                                            showingAddressSuggestions = false
                                            searchResults = []
                                        }
                                    }
                                
                                if showingAddressSuggestions && !searchResults.isEmpty {
                                    ScrollView {
                                        VStack(alignment: .leading) {
                                            ForEach(searchResults, id: \.placeID) { prediction in
                                                Button(action: {
                                                    selectLocation(prediction)
                                                    showingAddressSuggestions = false
                                                }) {
                                                    Text(prediction.attributedPrimaryText.string)
                                                        .lineLimit(1)
                                                }
                                                .padding(.vertical, 8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }
                                        .padding()
                                    }
                                    .frame(height: 200)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Price Range Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Price Range")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Min: $\(Int(minPrice))")
                                    Spacer()
                                    Text("Max: $\(Int(maxPrice))")
                                }
                                .foregroundColor(.gray)
                                
                                HStack {
                                    Text("$")
                                    Slider(value: $minPrice, in: 1...maxPrice, step: 1)
                                    Text("$$$")
                                }
                                
                                HStack {
                                    Text("$")
                                    Slider(value: $maxPrice, in: minPrice...100, step: 1)
                                    Text("$$$")
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Business Hours Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Business Hours")
                                .font(.headline)
                            
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
                        .disabled(isUploading || restaurantLicenseImage == nil || ownerIDImage == nil || address.isEmpty)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            (restaurantLicenseImage == nil || ownerIDImage == nil || address.isEmpty || isUploading) ?
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
    
    private func searchAddress(_ query: String) {
        let filter = GMSAutocompleteFilter()
        filter.countries = ["CA"] // Restrict to Canada
        filter.type = .address // Only show address results
        
        placesClient.findAutocompletePredictions(
            fromQuery: query,
            filter: filter,
            sessionToken: nil
        ) { (results, error) in
            if let error = error {
                print("Error fetching autocomplete results: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                self.searchResults = results ?? []
            }
        }
    }
    
    private func selectLocation(_ prediction: GMSAutocompletePrediction) {
        placesClient.fetchPlace(
            fromPlaceID: prediction.placeID,
            placeFields: [.name, .formattedAddress, .coordinate],
            sessionToken: nil
        ) { (place, error) in
            if let error = error {
                print("Error fetching place details: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                if let place = place {
                    self.address = place.formattedAddress ?? prediction.attributedPrimaryText.string
                    
                    // Also save the coordinates for later use
                    if let userId = self.authViewModel.currentUserId {
                        let locationData: [String: Any] = [
                            "name": place.name ?? "",
                            "address": place.formattedAddress ?? "",
                            "latitude": place.coordinate.latitude,
                            "longitude": place.coordinate.longitude
                        ]
                        
                        self.database.child("restaurants").child(userId).child("location").updateChildValues(locationData)
                    }
                }
            }
        }
    }
    
    private func submitDocuments() {
        guard let userId = authViewModel.currentUserId,
              let restaurantLicense = restaurantLicenseImage,
              let ownerID = ownerIDImage,
              !address.isEmpty else { return }
        
        isUploading = true
        
        // First save store info with address and price range
        saveStoreInfo { success in
            if !success {
                isUploading = false
                alertMessage = "Failed to save restaurant information"
                showAlert = true
                return
            }
            
            // Save business hours
            saveBusinessHours { success in
                if !success {
                    isUploading = false
                    alertMessage = "Failed to save business hours"
                    showAlert = true
                    return
                }
                
                // Then upload documents
                uploadDocuments(userId: userId, restaurantLicense: restaurantLicense, ownerID: ownerID)
            }
        }
    }
    
    private func saveStoreInfo(completion: @escaping (Bool) -> Void) {
        guard let userId = authViewModel.currentUserId else {
            completion(false)
            return
        }
        
        let db = Database.database().reference()
        let storeInfoRef = db.child("restaurants").child(userId).child("store_info")
        
        // Get existing store_info first
        storeInfoRef.observeSingleEvent(of: .value) { snapshot in
            var storeInfo: [String: Any] = [:]
            
            if let existingData = snapshot.value as? [String: Any] {
                storeInfo = existingData
            }
            
            // Add or update the new fields
            storeInfo["address"] = self.address
            storeInfo["price_range"] = [
                "min": Int(self.minPrice),
                "max": Int(self.maxPrice)
            ]
            
            // Save updated store_info
            storeInfoRef.updateChildValues(storeInfo) { error, _ in
                if let error = error {
                    print("Failed to save store info: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                completion(true)
            }
        }
    }
    
    private func saveBusinessHours(completion: @escaping (Bool) -> Void) {
        guard let userId = authViewModel.currentUserId else {
            completion(false)
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let hours = [
            "opening": formatter.string(from: openingTime),
            "closing": formatter.string(from: closingTime)
        ]
        
        let db = Database.database().reference()
        db.child("restaurants").child(userId).child("hours").setValue(hours) { error, _ in
            if let error = error {
                print("Failed to save business hours: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            completion(true)
        }
    }
    
    private func uploadDocuments(userId: String, restaurantLicense: UIImage, ownerID: UIImage) {
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