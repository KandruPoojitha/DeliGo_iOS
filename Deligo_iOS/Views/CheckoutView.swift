import SwiftUI
import FirebaseDatabase
import StripePaymentSheet

struct CheckoutView: View {
    @ObservedObject var cartManager: CartManager
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var deliveryOption: DeliveryOption = DeliveryOption.delivery
    @State private var paymentMethod: PaymentMethod = PaymentMethod.card
    @State private var tipPercentage: Double = 15.0
    @State private var deliveryAddress: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isProcessingPayment = false
    
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
                // Order Items Section
                orderItemsSection
                
                // Delivery Options Section
                deliveryOptionsSection
                
                // Delivery Address (if delivery selected)
                if deliveryOption == DeliveryOption.delivery {
                    deliveryAddressSection
                }
                
                // Tip Section
                tipSection
                
                // Payment Method Section
                paymentMethodSection
                
                // Order Summary Section
                orderSummarySection
                
                // Place Order Button
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Delivery Address")
                .font(.headline)
            
            TextEditor(text: $deliveryAddress)
                .frame(height: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            Divider()
        }
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
        if deliveryOption == DeliveryOption.delivery && deliveryAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
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
        
        if deliveryOption == DeliveryOption.delivery && deliveryAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                [
                    "id": item.id,
                    "menuItemId": item.menuItemId,
                    "name": item.name,
                    "description": item.description,
                    "price": item.price,
                    "imageURL": item.imageURL as Any,
                    "quantity": item.quantity,
                    "customizations": item.customizations,
                    "specialInstructions": item.specialInstructions,
                    "totalPrice": item.totalPrice
                ]
            },
            "subtotal": subtotal,
            "tipPercentage": tipPercentage,
            "tipAmount": tipAmount,
            "deliveryFee": deliveryOption == DeliveryOption.delivery ? deliveryFee : 0,
            "total": total,
            "deliveryOption": deliveryOption.rawValue,
            "paymentMethod": paymentMethod.rawValue,
            "deliveryAddress": deliveryOption == DeliveryOption.delivery ? deliveryAddress : nil,
            "status": status,
            "createdAt": ServerValue.timestamp()
        ]
        
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
                    
                    // Clear cart after successful order
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
