import SwiftUI
import FirebaseDatabase

struct RateOrderView: View {
    let order: CustomerOrder
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
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
    @State private var canRateDriver: Bool = false
    @State private var isDeliveryOrder: Bool = false
    
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
                    if canRateDriver {
                        Text("Driver").tag(1)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: selectedTab) { newValue in
                    print("Tab changed to: \(newValue)")
                }
                
                if isLoading {
                    ProgressView("Loading ratings...")
                        .padding()
                } else if selectedTab == 1 && !canRateDriver {
                    // We're on driver tab but cannot rate driver
                    VStack(spacing: 20) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No Driver to Rate")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("This order doesn't support driver rating.")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Rate Restaurant Instead") {
                            selectedTab = 0
                        }
                        .padding()
                        .background(Color(hex: "F4A261"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                } else {
                    if selectedTab == 0 {
                        // Restaurant rating view
                        restaurantRatingView
                    } else {
                        // Driver rating view for delivery orders
                        driverRatingView(driverId: order.driverId ?? "delivery_driver", driverName: order.driverName ?? "Delivery Driver")
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        isSubmitting = true
                        if selectedTab == 0 {
                            submitRating()
                        } else {
                            submitDriverRating { success in
                                DispatchQueue.main.async {
                                    isSubmitting = false
                                    if success {
                                        showSuccess = true
                                        successMessage = "Thank you for rating the driver!"
                                        
                                        // Save the rating in the customer's collection
                                        let customerId = order.userId
                                        let driverId = order.driverId ?? "delivery_driver"
                                        let actualDriverId = driverId.isEmpty && isDeliveryOrder ? "delivery_driver" : driverId
                                        
                                        let customerRatingsRef = database.child("customers/\(customerId)/ratingsAndComments/driver/\(actualDriverId)")
                                        customerRatingsRef.setValue(["rating": driverRating, "comment": driverComment]) { error, _ in
                                            if let error = error {
                                                print("ERROR saving driver rating to customer profile: \(error.localizedDescription)")
                                            } else {
                                                print("Successfully saved driver rating to customer profile")
                                            }
                                        }
                                        
                                        // Dismiss after showing success message
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }
                    }) {
                        Text("Submit Rating")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isSubmitting ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(isSubmitting || 
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
                // Check if this order is a delivery order
                isDeliveryOrder = (order.deliveryOption ?? "").lowercased() == "delivery"
                
                // Set canRateDriver based on driver ID or if it's a delivery order
                canRateDriver = (order.driverId != nil && !(order.driverId ?? "").isEmpty) || isDeliveryOrder
                
                print("Order delivery option: \(order.deliveryOption ?? "unknown")")
                print("Is delivery order: \(isDeliveryOrder)")
                print("Driver ID: \(order.driverId ?? "nil")")
                print("Can rate driver: \(canRateDriver)")
                
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
        
        if selectedTab == 0 {
            let restaurantRef = database.child("restaurants").child(order.restaurantId).child("ratingsandcomments")
            
            // Store rating under customer ID
            let ratingRef = restaurantRef.child("rating").child(order.userId)
            
            ratingRef.setValue(restaurantRating) { error, _ in
                if let error = error {
                    self.showError = true
                    self.errorMessage = "Failed to save restaurant rating: \(error.localizedDescription)"
                    self.isSubmitting = false
                    return
                }
                
                // Store comment if present
                if !self.restaurantComment.isEmpty {
                    let commentRef = restaurantRef.child("comment").child(self.order.userId)
                    commentRef.setValue(self.restaurantComment) { error, _ in
                        if let error = error {
                            self.showError = true
                            self.errorMessage = "Failed to save restaurant comment: \(error.localizedDescription)"
                            self.isSubmitting = false
                            return
                        }
                        self.handleRatingSuccess()
                    }
                } else {
                    self.handleRatingSuccess()
                }
            }
        }
    }
    
    private func handleRatingSuccess() {
        // Save the rating in the customer's collection
        let customerId = order.userId
        let customerRatingsRef = database.child("customers/\(customerId)/ratingsAndComments/restaurant/\(order.restaurantId)")
        customerRatingsRef.setValue(["rating": restaurantRating, "comment": restaurantComment]) { error, _ in
            if let error = error {
                print("ERROR saving restaurant rating to customer profile: \(error.localizedDescription)")
            } else {
                print("Successfully saved restaurant rating to customer profile")
            }
        }
        
        // Show success message and determine next steps
        showSuccess = true
        
        // If we have a driver to rate and on restaurant tab, prompt to rate driver
        if canRateDriver && selectedTab == 0 {
            successMessage = "Thank you for rating! Would you like to rate the driver as well?"
            
            // Switch to driver tab after showing message
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("Switching to driver tab after restaurant rating")
                selectedTab = 1 // Switch to driver tab
                isSubmitting = false
            }
        } else {
            // No driver to rate or already on driver tab
            successMessage = "Thank you for your rating!"
            
            // Dismiss after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isSubmitting = false
                dismiss()
            }
        }
    }
    
    private func submitDriverRating(completion: @escaping (Bool) -> Void) {
        // For delivery orders without a specific driver ID, use a generic ID
        let driverId = order.driverId ?? "delivery_driver"
        
        if driverId.isEmpty && !isDeliveryOrder {
            showError = true
            errorMessage = "Driver ID is missing. Please try again or contact support."
            print("ERROR: Cannot submit driver rating - missing driver ID and not a delivery order")
            completion(false)
            return
        }
        
        let actualDriverId = driverId.isEmpty ? "delivery_driver" : driverId
        
        print("Submitting driver rating for driverId: \(actualDriverId), orderId: \(order.id), rating: \(driverRating), comment: \(driverComment.isEmpty ? "None" : driverComment)")
        
        // Save in the driver's ratingsandcomments collection as requested
        let driverRef = database.child("drivers").child(actualDriverId).child("ratingsandcomments")
        
        // Store rating under customer ID
        let ratingRef = driverRef.child("rating").child(order.userId)
        ratingRef.setValue(driverRating) { error, _ in
            if let error = error {
                showError = true
                errorMessage = "Failed to save driver rating: \(error.localizedDescription)"
                print("ERROR saving driver rating: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            print("Successfully saved driver rating: \(driverRating)")
            
            // Store comment under customer ID if present
            if !driverComment.isEmpty {
                let commentRef = driverRef.child("comment").child(order.userId)
                commentRef.setValue(driverComment) { error, _ in
                    if let error = error {
                        showError = true
                        errorMessage = "Failed to save driver comment: \(error.localizedDescription)"
                        print("ERROR saving driver comment: \(error.localizedDescription)")
                        completion(false)
                        return
                    }
                    
                    print("Successfully saved driver comment")
                    completion(true)
                }
            } else {
                print("No driver comment to save")
                completion(true)
            }
        }
    }
    
    private func hasOrderBeenRated(completion: @escaping (Bool, Bool) -> Void) {
        let customerRatingsRef = database.child("customers/\(order.userId)/ratingsAndComments")
        
        // Check if restaurant has been rated
        customerRatingsRef.child("restaurant").child(order.restaurantId).observeSingleEvent(of: .value) { snapshot in
            let restaurantRated = snapshot.exists() && snapshot.value != nil
            
            // Check if driver has been rated (if applicable)
            if self.canRateDriver {
                let driverId = self.order.driverId ?? "delivery_driver"
                let actualDriverId = driverId.isEmpty && self.isDeliveryOrder ? "delivery_driver" : driverId
                
                if actualDriverId.isEmpty {
                    // No driver to rate
                    completion(restaurantRated, false)
                    return
                }
                
                customerRatingsRef.child("driver").child(actualDriverId).observeSingleEvent(of: .value) { snapshot in
                    let driverRated = snapshot.exists() && snapshot.value != nil
                    completion(restaurantRated, driverRated)
                }
            } else {
                // No driver to rate
                completion(restaurantRated, false)
            }
        }
    }
} 