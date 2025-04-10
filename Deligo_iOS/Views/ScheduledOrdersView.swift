import SwiftUI
import FirebaseDatabase

struct RestaurantScheduledOrder: Identifiable {
    var id: String
    var orderId: String
    var restaurantId: String
    var customerId: String
    var customerName: String
    var customerPhone: String?
    var items: [OrderItem]
    var total: Double
    var scheduledFor: Date
    var address: Address?
    var status: String
    var orderStatus: String
    
    struct OrderItem: Identifiable {
        var id: String
        var name: String
        var quantity: Int
        var price: Double
        var specialInstructions: String?
    }
    
    struct Address {
        var street: String
        var unit: String?
        var instructions: String?
    }
}

class ScheduledOrdersViewModel: ObservableObject {
    @Published var scheduledOrders: [RestaurantScheduledOrder] = []
    private var dbRef = Database.database().reference()
    private var restaurantId: String
    
    init(restaurantId: String) {
        self.restaurantId = restaurantId
        fetchScheduledOrders()
    }
    
    func fetchScheduledOrders() {
        let scheduledOrdersRef = dbRef.child("scheduled_orders")
        
        // Query for orders belonging to this restaurant
        scheduledOrdersRef.queryOrdered(byChild: "restaurantId").queryEqual(toValue: restaurantId).observe(.value) { snapshot, _ in
            guard let ordersData = snapshot.value as? [String: [String: Any]] else {
                self.scheduledOrders = []
                return
            }
            
            var newOrders: [RestaurantScheduledOrder] = []
            
            for (orderId, orderData) in ordersData {
                // Skip orders that aren't scheduled or have been processed
                if let status = orderData["status"] as? String,
                   (status == "accepted" || status == "rejected" || status == "completed") {
                    continue
                }
                
                // Convert scheduledFor timestamp to Date
                guard let scheduledForTimestamp = orderData["scheduledFor"] as? Double else { continue }
                let scheduledFor = Date(timeIntervalSince1970: scheduledForTimestamp)
                
                // Parse items
                var orderItems: [RestaurantScheduledOrder.OrderItem] = []
                if let items = orderData["items"] as? [[String: Any]] {
                    for item in items {
                        guard let id = item["id"] as? String,
                              let name = item["name"] as? String,
                              let quantity = item["quantity"] as? Int,
                              let price = item["price"] as? Double else { continue }
                        
                        let specialInstructions = item["specialInstructions"] as? String
                        
                        orderItems.append(RestaurantScheduledOrder.OrderItem(
                            id: id,
                            name: name,
                            quantity: quantity,
                            price: price,
                            specialInstructions: specialInstructions
                        ))
                    }
                }
                
                // Parse address if available
                var address: RestaurantScheduledOrder.Address?
                if let addressData = orderData["address"] as? [String: Any],
                   let street = addressData["street"] as? String {
                    let unit = addressData["unit"] as? String
                    let instructions = addressData["instructions"] as? String
                    address = RestaurantScheduledOrder.Address(
                        street: street,
                        unit: unit,
                        instructions: instructions
                    )
                }
                
                // Create ScheduledOrder object
                let order = RestaurantScheduledOrder(
                    id: orderId,
                    orderId: orderId,
                    restaurantId: orderData["restaurantId"] as? String ?? "",
                    customerId: orderData["customerId"] as? String ?? "",
                    customerName: orderData["customerName"] as? String ?? "Customer",
                    customerPhone: orderData["customerPhone"] as? String,
                    items: orderItems,
                    total: orderData["total"] as? Double ?? 0.0,
                    scheduledFor: scheduledFor,
                    address: address,
                    status: orderData["status"] as? String ?? "scheduled",
                    orderStatus: orderData["order_status"] as? String ?? "pending"
                )
                
                newOrders.append(order)
            }
            
            // Sort by scheduled date
            newOrders.sort { $0.scheduledFor < $1.scheduledFor }
            
            DispatchQueue.main.async {
                self.scheduledOrders = newOrders
            }
        }
    }
    
    func acceptOrder(order: RestaurantScheduledOrder) {
        // Move from scheduled_orders to regular orders collection
        let orderData = createRegularOrderData(from: order)
        
        // Update status in Firebase
        let orderRef = dbRef.child("orders").child(order.id)
        orderRef.setValue(orderData) { error, _ in
            if let error = error {
                print("Error accepting order: \(error.localizedDescription)")
                return
            }
            
            // Remove from scheduled_orders
            self.dbRef.child("scheduled_orders").child(order.id).removeValue()
        }
    }
    
    func rejectOrder(order: RestaurantScheduledOrder) {
        // Update status in Firebase
        let updates = [
            "status": "rejected",
            "order_status": "rejected"
        ]
        
        let orderRef = dbRef.child("scheduled_orders").child(order.id)
        orderRef.updateChildValues(updates) { error, _ in
            if let error = error {
                print("Error rejecting order: \(error.localizedDescription)")
                return
            }
            
            // Remove locally
            DispatchQueue.main.async {
                self.scheduledOrders.removeAll { $0.id == order.id }
            }
        }
    }
    
    private func createRegularOrderData(from scheduledOrder: RestaurantScheduledOrder) -> [String: Any] {
        // Create a dictionary with all the necessary order data
        var orderData: [String: Any] = [
            "id": scheduledOrder.id,
            "restaurantId": scheduledOrder.restaurantId,
            "customerId": scheduledOrder.customerId,
            "customerName": scheduledOrder.customerName,
            "total": scheduledOrder.total,
            "status": "in_progress",
            "order_status": "accepted",
            "createdAt": ServerValue.timestamp()
        ]
        
        // Add customer phone if available
        if let phone = scheduledOrder.customerPhone {
            orderData["customerPhone"] = phone
        }
        
        // Add address if available
        if let address = scheduledOrder.address {
            var addressData: [String: Any] = ["street": address.street]
            if let unit = address.unit {
                addressData["unit"] = unit
            }
            if let instructions = address.instructions {
                addressData["instructions"] = instructions
            }
            orderData["address"] = addressData
        }
        
        // Convert order items
        let items = scheduledOrder.items.map { item -> [String: Any] in
            var itemData: [String: Any] = [
                "id": item.id,
                "name": item.name,
                "quantity": item.quantity,
                "price": item.price
            ]
            
            if let instructions = item.specialInstructions {
                itemData["specialInstructions"] = instructions
            }
            
            return itemData
        }
        
        orderData["items"] = items
        
        return orderData
    }
}

struct ScheduledOrdersView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var viewModel: ScheduledOrdersViewModel
    @State private var selectedOrder: RestaurantScheduledOrder?
    @State private var showingAcceptConfirmation = false
    @State private var showingRejectConfirmation = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        // Initialize with the current restaurant's ID
        _viewModel = StateObject(wrappedValue: ScheduledOrdersViewModel(restaurantId: authViewModel.currentUserId ?? ""))
    }
    
    var body: some View {
        List {
            if viewModel.scheduledOrders.isEmpty {
                Text("No scheduled orders at this time")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(viewModel.scheduledOrders) { order in
                    ScheduledOrderRow(
                        order: order,
                        dateFormatter: dateFormatter,
                        onAccept: {
                            selectedOrder = order
                            showingAcceptConfirmation = true
                        },
                        onReject: {
                            selectedOrder = order
                            showingRejectConfirmation = true
                        }
                    )
                    .padding(.vertical, 8)
                }
            }
        }
        .refreshable {
            viewModel.fetchScheduledOrders()
        }
        .navigationTitle("Scheduled Orders")
        .alert("Accept Order", isPresented: $showingAcceptConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Accept") {
                if let order = selectedOrder {
                    viewModel.acceptOrder(order: order)
                }
            }
        } message: {
            Text("Are you sure you want to accept this order? The order will be moved to your active orders.")
        }
        .alert("Reject Order", isPresented: $showingRejectConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reject", role: .destructive) {
                if let order = selectedOrder {
                    viewModel.rejectOrder(order: order)
                }
            }
        } message: {
            Text("Are you sure you want to reject this order? This action cannot be undone.")
        }
        .onAppear {
            viewModel.fetchScheduledOrders()
        }
    }
}

struct ScheduledOrderRow: View {
    let order: RestaurantScheduledOrder
    let dateFormatter: DateFormatter
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Order #\(order.orderId.prefix(6))")
                    .font(.headline)
                Spacer()
                Text("$\(String(format: "%.2f", order.total))")
                    .fontWeight(.semibold)
            }
            
            Divider()
            
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.orange)
                Text("Scheduled for: \(dateFormatter.string(from: order.scheduledFor))")
                    .font(.subheadline)
            }
            
            HStack {
                Image(systemName: "person")
                    .foregroundColor(.blue)
                Text("Customer: \(order.customerName)")
                    .font(.subheadline)
            }
            
            if let phone = order.customerPhone {
                HStack {
                    Image(systemName: "phone")
                        .foregroundColor(.green)
                    Text("Phone: \(phone)")
                        .font(.subheadline)
                }
            }
            
            if let address = order.address {
                HStack(alignment: .top) {
                    Image(systemName: "location")
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Address: \(address.street)")
                        if let unit = address.unit {
                            Text("Unit: \(unit)")
                        }
                        if let instructions = address.instructions {
                            Text("Instructions: \(instructions)")
                        }
                    }
                    .font(.subheadline)
                }
            }
            
            Text("Items:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            ForEach(order.items) { item in
                HStack {
                    Text("• \(item.quantity)x \(item.name)")
                    Spacer()
                    Text("$\(String(format: "%.2f", item.price * Double(item.quantity)))")
                }
                .font(.subheadline)
                
                if let specialInstructions = item.specialInstructions, !specialInstructions.isEmpty {
                    Text("Note: \(specialInstructions)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.leading, 16)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: onAccept) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Accept")
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: onReject) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Reject")
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding(.top, 8)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
} 