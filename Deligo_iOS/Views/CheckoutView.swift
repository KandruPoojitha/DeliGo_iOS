import SwiftUI
import FirebaseDatabase
import StripePaymentSheet
import GooglePlaces

// Helper enums moved outside the struct
enum DeliveryOption: String, CaseIterable, Identifiable {
    case delivery = "Delivery"
    case pickup = "Pickup"
    
    var id: String { rawValue }
}

enum PaymentMethod: String, CaseIterable, Identifiable {
    case card = "Credit/Debit Card"
    case cod = "Cash on Delivery"
    
    var id: String { rawValue }
}

extension Encodable {
    var asDictionary: [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let dictionary = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            return [:]
        }
        return dictionary
    }
}

struct CheckoutView: View {
    @ObservedObject var cartManager: CartManager
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var locationSearchVM = LocationSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var deliveryOption: DeliveryOption = DeliveryOption.delivery
    @State private var paymentMethod: PaymentMethod = PaymentMethod.card
    @State private var tipPercentage: Double = 15.0
    @State private var deliveryAddress = DeliveryAddress(
        streetAddress: "",
        city: "",
        state: "",
        zipCode: "",
        unit: nil,
        instructions: nil,
        latitude: 0.0,
        longitude: 0.0,
        placeID: ""
    )
    @State private var unitText: String = ""
    @State private var instructionsText: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isProcessingPayment = false
    @State private var showingSuggestions = false
    @State private var restaurantDiscount: Int? = nil
    
    // Restaurant status variables
    @State private var isRestaurantOpen: Bool = true
    @State private var restaurantHours: [String: String] = [:]
    @State private var isScheduledOrder: Bool = false
    @State private var scheduledDate = Date().addingTimeInterval(3600) // Default to 1 hour from now
    
    private let tipOptions: [Double] = [0, 10, 15, 20, 25]
    private let deliveryFee: Double = 4.99
    private let db: DatabaseReference
    
    init(cartManager: CartManager, authViewModel: AuthViewModel) {
        self.cartManager = cartManager
        self.authViewModel = authViewModel
        self.db = Database.database().reference()
    }
    
    var subtotal: Double {
        let baseSubtotal = cartManager.totalCartPrice
        if let discount = restaurantDiscount {
            let discountAmount = (baseSubtotal * Double(discount)) / 100.0
            return baseSubtotal - discountAmount
        }
        return baseSubtotal
    }
    
    var tipAmount: Double {
        (subtotal * tipPercentage) / 100.0
    }
    
    var total: Double {
        subtotal + tipAmount + (deliveryOption == DeliveryOption.delivery ? deliveryFee : 0)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                orderItemsSection
                
                // Restaurant Status Section (if closed)
                if !isRestaurantOpen {
                    restaurantClosedSection
                }
                
                deliveryOptionsSection
                
                if deliveryOption == DeliveryOption.delivery {
                    deliveryAddressSection
                }
                
                tipSection
                paymentMethodSection
                orderSummarySection
                placeOrderButton
            }
            .padding()
        }
        .navigationTitle("Checkout")
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Order Status"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if alertMessage.contains("successfully") {
                        dismiss()
                    }
                }
            )
        }
        .onAppear {
            // Initialize the text fields from optional values
            unitText = deliveryAddress.unit ?? ""
            instructionsText = deliveryAddress.instructions ?? ""
            
            // Load restaurant discount and check if restaurant is open
            loadRestaurantInfo()
        }
    }
    
    private func loadRestaurantInfo() {
        guard let firstItem = cartManager.cartItems.first else { return }
        let restaurantId = firstItem.restaurantId
        
        db.child("restaurants").child(restaurantId).observeSingleEvent(of: .value) { snapshot, _ in
            if let dict = snapshot.value as? [String: Any] {
                // Check if restaurant is open
                if let isOpen = dict["isOpen"] as? Bool {
                    DispatchQueue.main.async {
                        self.isRestaurantOpen = isOpen
                    }
                }
                
                // Load restaurant hours
                if let hours = dict["hours"] as? [String: String] {
                    DispatchQueue.main.async {
                        self.restaurantHours = hours
                    }
                }
                
                // Check if discount field exists and is a valid integer
                if let discount = dict["discount"] as? Int, discount > 0 {
                    DispatchQueue.main.async {
                        self.restaurantDiscount = discount
                    }
                } else {
                    // If no discount field or invalid discount, set to nil
                    DispatchQueue.main.async {
                        self.restaurantDiscount = nil
                    }
                }
            }
        }
    }
    
    private var restaurantClosedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.red)
                Text("Restaurant is currently closed")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            
            if let openingTime = restaurantHours["opening"], let closingTime = restaurantHours["closing"] {
                Text("Opening Hours: \(openingTime) - \(closingTime)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Toggle("Schedule this order for later", isOn: $isScheduledOrder)
                .tint(Color(hex: "F4A261"))
                .onChange(of: isScheduledOrder) { _, newValue in
                    if newValue {
                        // Set default scheduled time to restaurant opening time if possible
                        if let openingTimeString = restaurantHours["opening"] {
                            if let scheduledTime = parseTimeString(openingTimeString) {
                                scheduledDate = scheduledTime
                            }
                        }
                    }
                }
            
            if isScheduledOrder {
                DatePicker(
                    "Schedule for:",
                    selection: $scheduledDate,
                    in: Date()...Date().addingTimeInterval(7*24*3600), // Limit to 1 week in the future
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(CompactDatePickerStyle())
            }
            
            Divider()
        }
    }
    
    private func parseTimeString(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        if let date = formatter.date(from: timeString) {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.hour, .minute], from: date)
            let today = calendar.dateComponents([.year, .month, .day], from: Date())
            
            components.year = today.year
            components.month = today.month
            components.day = today.day
            
            return calendar.date(from: components)
        }
        return nil
    }
    
    private var orderItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Items")
                .font(.headline)
            
            ForEach(cartManager.cartItems) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .font(.subheadline)
                        Text("Quantity: \(item.quantity)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text("$\(String(format: "%.2f", item.totalPrice))")
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }
            
            Divider()
        }
    }
    
    private var deliveryOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delivery Options")
                .font(.headline)
            
            Picker("Delivery Option", selection: $deliveryOption) {
                ForEach(DeliveryOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            if deliveryOption == DeliveryOption.delivery {
                Text("Delivery Fee: $\(String(format: "%.2f", deliveryFee))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Divider()
        }
    }
    
    private var deliveryAddressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delivery Address")
                .font(.headline)
            
            // Street Address with Suggestions
            VStack(alignment: .leading, spacing: 8) {
                Text("Street Address")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                TextField("Enter your street address", text: $locationSearchVM.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: locationSearchVM.searchText) { oldValue, newValue in
                        showingSuggestions = !newValue.isEmpty
                    }
                
                if showingSuggestions && !locationSearchVM.suggestions.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(locationSearchVM.suggestions) { suggestion in
                                Button(action: {
                                    locationSearchVM.selectLocation(suggestion)
                                    deliveryAddress.streetAddress = suggestion.title
                                    deliveryAddress.placeID = suggestion.placeID
                                    locationSearchVM.searchText = suggestion.title
                                    showingSuggestions = false
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(suggestion.title)
                                            .font(.subheadline)
                                        Text(suggestion.subtitle)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.vertical, 8)
                                Divider()
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                    }
                    .frame(maxHeight: 200)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Unit/Apartment Number (Optional)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                TextField("Enter unit or apartment number", text: $unitText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: unitText) { _, newValue in
                        deliveryAddress.unit = newValue.isEmpty ? nil : newValue
                    }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Delivery Instructions (Optional)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                TextEditor(text: $instructionsText)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .onChange(of: instructionsText) { _, newValue in
                        deliveryAddress.instructions = newValue.isEmpty ? nil : newValue
                    }
            }
            
            Divider()
        }
        .padding(.horizontal)
    }
    
    private var tipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a Tip")
                .font(.headline)
            
            HStack {
                ForEach(tipOptions, id: \.self) { percentage in
                    Button(action: {
                        tipPercentage = percentage
                    }) {
                        Text("\(Int(percentage))%")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(tipPercentage == percentage ? Color(hex: "F4A261") : Color(.systemGray6))
                            .foregroundColor(tipPercentage == percentage ? .white : .primary)
                            .cornerRadius(20)
                    }
                }
            }
            
            if tipPercentage > 0 {
                Text("Tip Amount: $\(String(format: "%.2f", tipAmount))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Divider()
        }
    }
    
    private var paymentMethodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Method")
                .font(.headline)
            
            Picker("Payment Method", selection: $paymentMethod) {
                ForEach(PaymentMethod.allCases) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Divider()
        }
    }
    
    private var orderSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Summary")
                .font(.headline)
            
            HStack {
                Text("Subtotal")
                Spacer()
                Text("$\(String(format: "%.2f", cartManager.totalCartPrice))")
            }
            
            if let discount = restaurantDiscount {
                HStack {
                    Text("Discount (\(discount)%)")
                    Spacer()
                    Text("-$\(String(format: "%.2f", (cartManager.totalCartPrice * Double(discount)) / 100.0))")
                        .foregroundColor(.green)
                }
            }
            
            HStack {
                Text("Tip (\(Int(tipPercentage))%)")
                Spacer()
                Text("$\(String(format: "%.2f", tipAmount))")
            }
            
            if deliveryOption == DeliveryOption.delivery {
                HStack {
                    Text("Delivery Fee")
                    Spacer()
                    Text("$\(String(format: "%.2f", deliveryFee))")
                }
            }
            
            Divider()
            
            HStack {
                Text("Total")
                    .fontWeight(.bold)
                Spacer()
                Text("$\(String(format: "%.2f", total))")
                    .fontWeight(.bold)
            }
        }
    }
    
    private var placeOrderButton: some View {
        Button(action: placeOrder) {
            HStack {
                if isProcessingPayment {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, 8)
                }
                
                Text(isProcessingPayment ? "Processing..." : isScheduledOrder ? "Schedule Order" : "Place Order")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isValidOrder ? Color(hex: "F4A261") : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!isValidOrder || isProcessingPayment)
    }
    
    private var isValidOrder: Bool {
        // Basic validation
        let isAddressValid = deliveryOption != DeliveryOption.delivery || 
            !deliveryAddress.streetAddress.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
        
        // Restaurant is open OR it's a scheduled order
        let isTimingValid = isRestaurantOpen || isScheduledOrder
        
        return !cartManager.cartItems.isEmpty && isAddressValid && isTimingValid
    }
    
    private func placeOrder() {
        guard let userId = authViewModel.currentUserId else {
            alertMessage = "Error: User not logged in"
            showingAlert = true
            return
        }
        
        guard !cartManager.cartItems.isEmpty else {
            alertMessage = "Error: Cart is empty"
            showingAlert = true
            return
        }
        
        if deliveryOption == DeliveryOption.delivery && deliveryAddress.streetAddress.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            alertMessage = "Error: Please provide a delivery address"
            showingAlert = true
            return
        }
        
        if !isRestaurantOpen && !isScheduledOrder {
            alertMessage = "Error: Restaurant is closed. Please schedule your order for later."
            showingAlert = true
            return
        }
        
        isProcessingPayment = true
        
        switch paymentMethod {
        case .card:
            processCardPayment(userId: userId)
        case .cod:
            processCODOrder(userId: userId)
        }
    }
    
    private func processCardPayment(userId: String) {
        // Initialize Stripe payment
        StripeManager.shared.handlePayment(amount: total) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let paymentIntentId):
                    if self.isScheduledOrder {
                        self.createScheduledOrder(userId: userId, status: "scheduled", paymentIntentId: paymentIntentId)
                    } else {
                        self.createOrder(userId: userId, status: "pending", paymentIntentId: paymentIntentId)
                    }
                case .failure(let error):
                    self.isProcessingPayment = false
                    self.alertMessage = "Payment failed: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func processCODOrder(userId: String) {
        if isScheduledOrder {
            createScheduledOrder(userId: userId, status: "scheduled", paymentIntentId: nil)
        } else {
            createOrder(userId: userId, status: "pending", paymentIntentId: nil)
        }
    }
    
    private func createScheduledOrder(userId: String, status: String, paymentIntentId: String?) {
        let orderId = UUID().uuidString
        
        // Get the restaurant ID from the first cart item
        guard let firstItem = cartManager.cartItems.first else {
            alertMessage = "No items in cart. Unable to create order."
            showingAlert = true
            isProcessingPayment = false
            return
        }
        
        let restaurantId = firstItem.restaurantId
        
        // Convert scheduled date to timestamp
        let scheduledTimestamp = scheduledDate.timeIntervalSince1970
        
        // Create order data (similar to regular order but with scheduling info)
        var orderData = prepareOrderData(orderId: orderId, userId: userId, restaurantId: restaurantId, status: status, paymentIntentId: paymentIntentId)
        
        // Add scheduling information
        orderData["scheduledFor"] = scheduledTimestamp
        orderData["isScheduled"] = true
        
        // Store in scheduled_orders path
        saveToFirebase(path: "scheduled_orders", orderId: orderId, orderData: orderData)
    }
    
    private func createOrder(userId: String, status: String, paymentIntentId: String?) {
        let orderId = UUID().uuidString
        
        // Get the restaurant ID from the first cart item
        guard let firstItem = cartManager.cartItems.first else {
            alertMessage = "No items in cart. Unable to create order."
            showingAlert = true
            isProcessingPayment = false
            return
        }
        
        let restaurantId = firstItem.restaurantId
        
        // Create order data
        let orderData = prepareOrderData(orderId: orderId, userId: userId, restaurantId: restaurantId, status: status, paymentIntentId: paymentIntentId)
        
        // Store in regular orders path
        saveToFirebase(path: "orders", orderId: orderId, orderData: orderData)
    }
    
    private func prepareOrderData(orderId: String, userId: String, restaurantId: String, status: String, paymentIntentId: String?) -> [String: Any] {
        // Create base order data that's common between regular and scheduled orders
        var orderData: [String: Any] = [
            "id": orderId,
            "userId": userId,
            "restaurantId": restaurantId,
            "items": cartManager.cartItems.map { item in
                var itemDict: [String: Any] = [
                    "id": item.id,
                    "menuItemId": item.menuItemId,
                    "name": item.name,
                    "description": item.description,
                    "price": item.price,
                    "quantity": item.quantity,
                    "totalPrice": item.totalPrice
                ]
                
                if let imageURL = item.imageURL {
                    itemDict["imageURL"] = imageURL
                }
                
                if !item.specialInstructions.isEmpty {
                    itemDict["specialInstructions"] = item.specialInstructions
                }
                
                // Convert customizations to compatible format
                var convertedCustomizations: [String: [[String: Any]]] = [:]
                for (key, selections) in item.customizations {
                    let mappedSelections: [[String: Any]] = selections.map { selection in
                        var selectionDict: [String: Any] = [
                            "optionId": selection.optionId,
                            "optionName": selection.optionName
                        ]
                        
                        let selectedItemsArray: [[String: Any]] = selection.selectedItems.map { item in
                            [
                                "id": item.id,
                                "name": item.name,
                                "price": item.price
                            ]
                        }
                        
                        selectionDict["selectedItems"] = selectedItemsArray
                        return selectionDict
                    }
                    convertedCustomizations[key] = mappedSelections
                }
                
                itemDict["customizations"] = convertedCustomizations
                return itemDict
            },
            "subtotal": cartManager.totalCartPrice,
            "discountPercentage": restaurantDiscount ?? 0,
            "discountAmount": restaurantDiscount != nil ? (cartManager.totalCartPrice * Double(restaurantDiscount!)) / 100.0 : 0,
            "tipPercentage": tipPercentage,
            "tipAmount": tipAmount,
            "deliveryFee": deliveryOption == DeliveryOption.delivery ? deliveryFee : 0,
            "total": total,
            "deliveryOption": deliveryOption.rawValue,
            "paymentMethod": paymentMethod.rawValue,
            "status": status,
            "order_status": "pending",
            "createdAt": ServerValue.timestamp(),
            "customerId": userId
        ]
        
        if deliveryOption == DeliveryOption.delivery {
            var addressData: [String: Any] = ["street": deliveryAddress.streetAddress]
            
            if let unit = deliveryAddress.unit, !unit.isEmpty {
                addressData["unit"] = unit
            }
            
            if let instructions = deliveryAddress.instructions, !instructions.isEmpty {
                addressData["instructions"] = instructions
            }
            
            orderData["address"] = addressData
            
            // Store latitude and longitude at the root level
            orderData["latitude"] = locationSearchVM.selectedLocation?.coordinate.latitude ?? 0
            orderData["longitude"] = locationSearchVM.selectedLocation?.coordinate.longitude ?? 0
        }
        
        if let paymentIntentId = paymentIntentId {
            orderData["paymentIntentId"] = paymentIntentId
        }
        
        return orderData
    }
    
    private func saveToFirebase(path: String, orderId: String, orderData: [String: Any]) {
        guard let userId = authViewModel.currentUserId else { return }
        
        // Get customer information from Firebase
        let userRef = db.child("customers").child(userId)
        userRef.observeSingleEvent(of: .value) { snapshot, _ in
            // Create a mutable copy of the order data
            var updatedOrderData = orderData
            
            if let userData = snapshot.value as? [String: Any] {
                // Add available customer information
                if let fullName = userData["fullName"] as? String {
                    updatedOrderData["customerName"] = fullName
                }
                
                if let phone = userData["phone"] as? String {
                    updatedOrderData["customerPhone"] = phone
                }
            }
            
            // Save to appropriate Firebase path
            let orderRef = self.db.child(path).child(orderId)
            orderRef.setValue(updatedOrderData) { error, _ in
                DispatchQueue.main.async {
                    self.isProcessingPayment = false
                    
                    if let error = error {
                        print("Error placing order: \(error.localizedDescription)")
                        self.alertMessage = "Error placing order: \(error.localizedDescription)"
                        self.showingAlert = true
                        return
                    }
                    
                    self.cartManager.clearCart()
                    
                    if path == "scheduled_orders" {
                        self.alertMessage = "Order scheduled successfully for \(self.formatDate(self.scheduledDate))!"
                    } else {
                        self.alertMessage = "Order placed successfully!"
                    }
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
        
