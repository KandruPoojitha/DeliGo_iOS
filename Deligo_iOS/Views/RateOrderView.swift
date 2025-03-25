import SwiftUI
import FirebaseDatabase

struct RateOrderView: View {
    let order: CustomerOrder
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Int // 0 for restaurant, 1 for driver
    @State private var restaurantRating: Int = 0 // Start with 0 and load from Firebase
    @State private var driverRating: Int = 0 // Start with 0 and load from Firebase
    @State private var restaurantComment: String = ""
    @State private var driverComment: String = ""
    @State private var isSubmitting = false
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = "Thank you for your feedback!"
    
    init(order: CustomerOrder, authViewModel: AuthViewModel, initialTab: Int = 0) {
        self.order = order
        self.authViewModel = authViewModel
        _selectedTab = State(initialValue: initialTab)
    }
    
    private let database = Database.database().reference()
    
    var body: some View {
        NavigationView {
            VStack {
                // Tab selector for restaurant vs driver rating
                Picker("Rating Type", selection: $selectedTab) {
                    Text("Restaurant").tag(0)
                    Text("Driver").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .disabled(order.driverId == nil)
                
                if isLoading {
                    ProgressView("Loading ratings...")
                        .padding()
                } else {
                    if selectedTab == 0 {
                        // Restaurant rating view
                        restaurantRatingView
                    } else {
                        // Driver rating view
                        if let driverId = order.driverId, let driverName = order.driverName {
                            driverRatingView(driverId: driverId, driverName: driverName)
                        } else {
                            VStack(spacing: 20) {
                                Image(systemName: "person.fill.questionmark")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                
                                Text("No Driver Assigned")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                
                                Text("This order doesn't have a delivery driver to rate.")
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding()
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: submitRating) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Submit Rating")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "F4A261"))
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                    }
                    .disabled(isSubmitting || (selectedTab == 1 && order.driverId == nil) || 
                              (selectedTab == 0 && restaurantRating == 0) || 
                              (selectedTab == 1 && driverRating == 0))
                    .padding(.bottom)
                }
            }
            .navigationTitle("Rate \(selectedTab == 0 ? "Restaurant" : "Driver")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Rating Submitted", isPresented: $showSuccess) {
                Button("OK", role: .cancel) {
                    // No dismissal here - let the submitRating function handle it
                }
            } message: {
                Text(successMessage)
            }
            .onAppear {
                loadExistingRatings()
            }
        }
    }
    
    private func loadExistingRatings() {
        isLoading = true
        
        // Load restaurant rating
        let restaurantRatingRef = database.child("restaurants")
            .child(order.restaurantId)
            .child("ratingsandcomments")
            .child("rating")
            .child(order.userId)
        
        restaurantRatingRef.observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists(), let rating = snapshot.value as? Int {
                self.restaurantRating = rating
                print("Loaded existing restaurant rating: \(rating)")
            } else {
                // Default to 5 if no existing rating
                self.restaurantRating = 5
            }
            
            // Load restaurant comment
            let restaurantCommentRef = database.child("restaurants")
                .child(order.restaurantId)
                .child("ratingsandcomments")
                .child("comment")
                .child(order.userId)
            
            restaurantCommentRef.observeSingleEvent(of: .value) { snapshot in
                if snapshot.exists(), let comment = snapshot.value as? String {
                    self.restaurantComment = comment
                    print("Loaded existing restaurant comment")
                }
                
                // Load driver rating if applicable
                if let driverId = order.driverId {
                    let driverRatingRef = database.child("drivers")
                        .child(driverId)
                        .child("ratingsandcomments")
                        .child("rating")
                        .child(order.userId)
                    
                    driverRatingRef.observeSingleEvent(of: .value) { snapshot in
                        if snapshot.exists(), let rating = snapshot.value as? Int {
                            self.driverRating = rating
                            print("Loaded existing driver rating: \(rating)")
                        } else {
                            // Default to 5 if no existing rating
                            self.driverRating = 5
                        }
                        
                        // Load driver comment
                        let driverCommentRef = database.child("drivers")
                            .child(driverId)
                            .child("ratingsandcomments")
                            .child("comment")
                            .child(order.userId)
                        
                        driverCommentRef.observeSingleEvent(of: .value) { snapshot in
                            if snapshot.exists(), let comment = snapshot.value as? String {
                                self.driverComment = comment
                                print("Loaded existing driver comment")
                            }
                            
                            isLoading = false
                        }
                    }
                } else {
                    isLoading = false
                }
            }
        }
    }
    
    private var restaurantRatingView: some View {
        Form {
            Section(header: Text("Rate the restaurant")) {
                HStack {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= restaurantRating ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                            .font(.title2)
                            .onTapGesture {
                                restaurantRating = index
                            }
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            
            Section(header: Text("Comments about the restaurant (Optional)")) {
                TextEditor(text: $restaurantComment)
                    .frame(height: 100)
            }
        }
    }
    
    private func driverRatingView(driverId: String, driverName: String) -> some View {
        Form {
            Section(header: Text("Rate driver: \(driverName)")) {
                HStack {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= driverRating ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                            .font(.title2)
                            .onTapGesture {
                                driverRating = index
                            }
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            
            Section(header: Text("Comments about the driver (Optional)")) {
                TextEditor(text: $driverComment)
                    .frame(height: 100)
            }
        }
    }
    
    private func submitRating() {
        isSubmitting = true
        
        // Determine which rating to submit based on the selected tab
        if selectedTab == 0 {
            // Submit restaurant rating
            submitRestaurantRating { success in
                isSubmitting = false
                
                if !success {
                    return
                }
                
                // If driver exists and not already submitted, ask if user wants to rate driver too
                if let driverId = order.driverId, !driverId.isEmpty, order.driverRating == nil {
                    // Set success message to encourage driver rating
                    successMessage = "Restaurant rating submitted! Would you like to rate your driver too?"
                    showSuccess = true
                    
                    // After success alert is dismissed, switch to driver tab
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        selectedTab = 1 // Switch to driver tab
                    }
                } else {
                    // Final success message if no driver or driver already rated
                    successMessage = "Thank you for rating the restaurant!"
                    showSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        dismiss()
                    }
                }
            }
        } else {
            // Submit driver rating
            submitDriverRating { success in
                isSubmitting = false
                if success {
                    successMessage = "Thank you for rating your driver!"
                    showSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func submitRestaurantRating(completion: @escaping (Bool) -> Void) {
        guard !order.restaurantId.isEmpty else {
            showError = true
            errorMessage = "Restaurant ID is missing. Please try again."
            completion(false)
            return
        }
        
        print("Submitting restaurant rating for restaurantId: \(order.restaurantId), orderId: \(order.id)")
        
        // Save in the restaurant's ratingsandcomments collection as requested
        let restaurantRef = database.child("restaurants").child(order.restaurantId).child("ratingsandcomments")
        
        // Store rating under customer ID
        let ratingRef = restaurantRef.child("rating").child(order.userId)
        ratingRef.setValue(restaurantRating) { error, _ in
            if let error = error {
                showError = true
                errorMessage = "Failed to save rating: \(error.localizedDescription)"
                completion(false)
                return
            }
            
            // Store comment under customer ID if present
            if !restaurantComment.isEmpty {
                let commentRef = restaurantRef.child("comment").child(order.userId)
                commentRef.setValue(restaurantComment) { error, _ in
                    if let error = error {
                        showError = true
                        errorMessage = "Failed to save comment: \(error.localizedDescription)"
                        completion(false)
                        return
                    }
                    
                    completion(true)
                }
            } else {
                completion(true)
            }
        }
    }
    
    private func submitDriverRating(completion: @escaping (Bool) -> Void) {
        guard let driverId = order.driverId, !driverId.isEmpty else {
            showError = true
            errorMessage = "Driver ID is missing. Please try again or contact support."
            completion(false)
            return
        }
        
        print("Submitting driver rating for driverId: \(driverId), orderId: \(order.id)")
        
        // Save in the driver's ratingsandcomments collection as requested
        let driverRef = database.child("drivers").child(driverId).child("ratingsandcomments")
        
        // Store rating under customer ID
        let ratingRef = driverRef.child("rating").child(order.userId)
        ratingRef.setValue(driverRating) { error, _ in
            if let error = error {
                showError = true
                errorMessage = "Failed to save rating: \(error.localizedDescription)"
                completion(false)
                return
            }
            
            // Store comment under customer ID if present
            if !driverComment.isEmpty {
                let commentRef = driverRef.child("comment").child(order.userId)
                commentRef.setValue(driverComment) { error, _ in
                    if let error = error {
                        showError = true
                        errorMessage = "Failed to save comment: \(error.localizedDescription)"
                        completion(false)
                        return
                    }
                    
                    completion(true)
                }
            } else {
                completion(true)
            }
        }
    }
} 