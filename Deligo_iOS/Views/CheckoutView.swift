import SwiftUI
import FirebaseDatabase
import StripePaymentSheet
import GooglePlaces

struct CheckoutView: View {
    @ObservedObject var cartManager: CartManager
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var locationSearchVM = LocationSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var deliveryOption: DeliveryOption = DeliveryOption.delivery
    @State private var paymentMethod: PaymentMethod = PaymentMethod.card
    @State private var tipPercentage: Double = 15.0
    @State private var deliveryAddress = DeliveryAddress(streetAddress: "", unit: "", instructions: "")
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isProcessingPayment = false
    @State private var showingSuggestions = false
    
    private let tipOptions: [Double] = [0, 10, 15, 20, 25]
    private let deliveryFee: Double = 4.99
    private let db: DatabaseReference
    
    init(cartManager: CartManager, authViewModel: AuthViewModel) {
        self.cartManager = cartManager
        self.authViewModel = authViewModel
        self.db = Database.database().reference()
    }
    
    var subtotal: Double {
        cartManager.totalCartPrice
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
                    .onChange(of: locationSearchVM.searchText) { _ in
                        showingSuggestions = !locationSearchVM.searchText.isEmpty
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
                
                TextField("Enter unit or apartment number", text: $deliveryAddress.unit)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Delivery Instructions (Optional)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                TextEditor(text: $deliveryAddress.instructions)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
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
            
            VStack(spacing: 8) {
                HStack {
                    Text("Subtotal")
                    Spacer()
                    Text("$\(String(format: "%.2f", subtotal))")
                }
                
                if tipPercentage > 0 {
                    HStack {
                        Text("Tip (\(Int(tipPercentage))%)")
                        Spacer()
                        Text("$\(String(format: "%.2f", tipAmount))")
                    }
                }
                
                if deliveryOption == DeliveryOption.delivery {
                    HStack {
                        Text("Delivery Fee")
                        Spacer()
                        Text("$\(String(format: "%.2f", deliveryFee))")
                    }
                }
                
                HStack {
                    Text("Total")
                        .fontWeight(.bold)
                    Spacer()
                    Text("$\(String(format: "%.2f", total))")
                        .fontWeight(.bold)
                }
            }
            .font(.subheadline)
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
                
                Text(isProcessingPayment ? "Processing..." : "Place Order")
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
        if deliveryOption == DeliveryOption.delivery {
            return !deliveryAddress.streetAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !cartManager.cartItems.isEmpty
        }
        return !cartManager.cartItems.isEmpty
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
        
        if deliveryOption == DeliveryOption.delivery && deliveryAddress.streetAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            alertMessage = "Error: Please provide a delivery address"
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
                    self.createOrder(userId: userId, status: "paid", paymentIntentId: paymentIntentId)
                case .failure(let error):
                    self.isProcessingPayment = false
                    self.alertMessage = "Payment failed: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func processCODOrder(userId: String) {
        createOrder(userId: userId, status: "pending", paymentIntentId: nil)
    }
    
    private func createOrder(userId: String, status: String, paymentIntentId: String?) {
        let orderId = UUID().uuidString
        var orderData: [String: Any] = [
            "id": orderId,
            "userId": userId,
            "restaurantId": cartManager.cartItems.first?.menuItemId ?? "",
            "items": cartManager.cartItems.map { item in
                var itemDict: [String: Any] = [
                    "id": item.id,
                    "menuItemId": item.menuItemId,
                    "name": item.name,
                    "description": item.description,
                    "price": item.price,
                    "quantity": item.quantity,
                    "specialInstructions": item.specialInstructions,
                    "totalPrice": item.totalPrice
                ]
                
                if let imageURL = item.imageURL {
                    itemDict["imageURL"] = imageURL
                }
                
                // Convert customizations to compatible format
                var convertedCustomizations: [String: [[String: Any]]] = [:]
                for (key, selections) in item.customizations {
                    convertedCustomizations[key] = selections.map { selection in
                        var selectionDict: [String: Any] = [
                            "optionId": selection.optionId,
                            "optionName": selection.optionName
                        ]
                        
                        selectionDict["selectedItems"] = selection.selectedItems.map { item in
                            return [
                                "id": item.id,
                                "name": item.name,
                                "price": item.price
                            ]
                        }
                        
                        return selectionDict
                    }
                }
                
                itemDict["customizations"] = convertedCustomizations
                return itemDict
            },
            "subtotal": subtotal,
            "tipPercentage": tipPercentage,
            "tipAmount": tipAmount,
            "deliveryFee": deliveryOption == DeliveryOption.delivery ? deliveryFee : 0,
            "total": total,
            "deliveryOption": deliveryOption.rawValue,
            "paymentMethod": paymentMethod.rawValue,
            "status": status,
            "createdAt": ServerValue.timestamp()
        ]
        
        if deliveryOption == DeliveryOption.delivery {
            orderData["address"] = [
                "street": deliveryAddress.streetAddress,
                "unit": deliveryAddress.unit,
                "instructions": deliveryAddress.instructions
            ]
            
            // Store latitude and longitude at the root level
            orderData["latitude"] = locationSearchVM.selectedLocation?.coordinate.latitude ?? 0
            orderData["longitude"] = locationSearchVM.selectedLocation?.coordinate.longitude ?? 0
        }
        
        if let paymentIntentId = paymentIntentId {
            orderData["paymentIntentId"] = paymentIntentId
        }
        
        // Save order to Firebase with connection check
        let orderRef = db.child("orders").child(orderId)
        
        // Check connection status
        let connectedRef = Database.database().reference(withPath: ".info/connected")
        connectedRef.observe(.value) { snapshot, _ in
            guard let connected = snapshot.value as? Bool, connected else {
                DispatchQueue.main.async {
                    isProcessingPayment = false
                    alertMessage = "Error: No internet connection. Please try again."
                    showingAlert = true
                }
                return
            }
            
            // We're connected, proceed with order creation
            orderRef.setValue(orderData) { error, _ in
                DispatchQueue.main.async {
                    isProcessingPayment = false
                    
                    if let error = error {
                        print("Error placing order: \(error.localizedDescription)")
                        alertMessage = "Error placing order: \(error.localizedDescription)"
                        showingAlert = true
                        return
                    }
                    
                    cartManager.clearCart()
                    alertMessage = "Order placed successfully!"
                    showingAlert = true
                }
            }
        }
    }
}

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
