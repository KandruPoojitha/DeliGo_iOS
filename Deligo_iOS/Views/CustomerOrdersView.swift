import SwiftUI
import FirebaseDatabase

struct CustomerOrdersView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    @State private var orders: [CustomerOrder] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack {
                // Tab selector
                Picker("Order Status", selection: $selectedTab) {
                    Text("Current").tag(0)
                    Text("Past").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if isLoading {
                    ProgressView("Loading orders...")
                } else if orders.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: selectedTab == 0 ? "hourglass" : "checkmark.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text(selectedTab == 0 ? "No Current Orders" : "No Past Orders")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text(selectedTab == 0 ? "Your current orders will appear here" : "Your order history will appear here")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Refresh") {
                            loadOrders()
                        }
                        .padding()
                        .background(Color(hex: "F4A261"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.top, 10)
                    }
                    .padding()
                } else {
                    // Order list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredOrders) { order in
                                CustomerOrderCard(order: order)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        loadOrders()
                    }
                }
            }
            .navigationTitle("My Orders")
            .onAppear {
                loadOrders()
            }
        }
    }
    
    private var filteredOrders: [CustomerOrder] {
        if selectedTab == 0 {
            // Current orders - pending, accepted, preparing, assigned_driver, picked_up
            return orders.filter { 
                let status = $0.status.lowercased()
                return status != "delivered" && status != "cancelled"
            }
        } else {
            // Past orders - delivered, cancelled
            return orders.filter { 
                let status = $0.status.lowercased()
                return status == "delivered" || status == "cancelled" 
            }
        }
    }
    
    private func loadOrders() {
        guard let userId = authViewModel.currentUserId else {
            isLoading = false
            return
        }
        
        isLoading = true
        let database = Database.database().reference()
        
        database.child("orders")
            .queryOrdered(byChild: "userId")
            .queryEqual(toValue: userId)
            .observe(.value) { snapshot in
                var newOrders: [CustomerOrder] = []
                
                for child in snapshot.children {
                    guard let snapshot = child as? DataSnapshot,
                          let data = snapshot.value as? [String: Any] else { continue }
                    
                    if let order = CustomerOrder(id: snapshot.key, data: data) {
                        newOrders.append(order)
                    }
                }
                
                // Sort orders by creation time, newest first
                newOrders.sort { $0.createdAt > $1.createdAt }
                
                DispatchQueue.main.async {
                    self.orders = newOrders
                    self.isLoading = false
                    print("Loaded \(newOrders.count) orders for customer")
                }
            }
    }
}

struct CustomerOrderCard: View {
    let order: CustomerOrder
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Order header with toggle
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(order.restaurantName)
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("$\(String(format: "%.2f", order.total))")
                                .fontWeight(.semibold)
                                .foregroundColor(Color(hex: "F4A261"))
                        }
                        
                        HStack {
                            Text("Order #\(order.id.prefix(8))")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text(formattedDate(from: order.createdAt))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Status badge
            HStack {
                Spacer()
                
                Text(order.orderStatusDisplay.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
            }
            
            if isExpanded {
                Divider()
                
                // Delivery details if applicable
                if order.deliveryOption.lowercased() == "delivery" {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Delivery Address:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(order.address)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
                
                // Order items
                VStack(alignment: .leading, spacing: 8) {
                    Text("Items:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(order.items) { item in
                        HStack {
                            Text("\(item.quantity)x")
                                .foregroundColor(.gray)
                            Text(item.name)
                            Spacer()
                            Text("$\(String(format: "%.2f", item.totalPrice))")
                                .foregroundColor(.gray)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
                
                // Price breakdown
                Divider()
                
                VStack(spacing: 6) {
                    HStack {
                        Text("Subtotal")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("$\(String(format: "%.2f", order.subtotal))")
                    }
                    .font(.subheadline)
                    
                    HStack {
                        Text("Delivery Fee")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("$\(String(format: "%.2f", order.deliveryFee))")
                    }
                    .font(.subheadline)
                    
                    HStack {
                        Text("Total")
                            .fontWeight(.bold)
                        Spacer()
                        Text("$\(String(format: "%.2f", order.total))")
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "F4A261"))
                    }
                    .font(.subheadline)
                }
                .padding(.vertical, 4)
                
                // Driver info if assigned
                if let driverName = order.driverName, !driverName.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Driver:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(driverName)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
    
    private var statusColor: Color {
        switch order.status.lowercased() {
        case "pending":
            return .orange
        case "accepted", "in_progress", "preparing", "ready_for_pickup":
            return .blue
        case "assigned_driver":
            return .purple
        case "picked_up", "delivering":
            return Color(hex: "4CAF50") // Green
        case "delivered":
            return .green
        case "cancelled", "rejected":
            return .red
        default:
            return .gray
        }
    }
    
    private func formattedDate(from timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CustomerOrder: Identifiable {
    let id: String
    let restaurantId: String
    let restaurantName: String
    let userId: String
    let items: [CustomerOrderItem]
    let status: String
    let orderStatus: String
    let total: Double
    let subtotal: Double
    let deliveryFee: Double
    let deliveryOption: String
    let address: String
    let createdAt: TimeInterval
    let updatedAt: TimeInterval
    let driverId: String?
    let driverName: String?
    
    var orderStatusDisplay: String {
        switch (status.lowercased(), orderStatus.lowercased()) {
        case ("pending", _):
            return "Pending"
        case ("in_progress", "accepted"), (_, "accepted"):
            return "Accepted"
        case (_, "preparing"):
            return "Preparing"
        case ("assigned_driver", _):
            return "Driver Assigned"
        case ("picked_up", _), (_, "picked_up"):
            return "On The Way"
        case ("delivering", _), (_, "delivering"):
            return "Out For Delivery"
        case ("delivered", _), (_, "delivered"):
            return "Delivered"
        case ("cancelled", _), (_, "cancelled"), ("rejected", _):
            return "Cancelled"
        default:
            return status.capitalized
        }
    }
    
    init?(id: String, data: [String: Any]) {
        self.id = id
        
        // Basic order information
        guard let restaurantId = data["restaurantId"] as? String,
              let total = data["total"] as? Double else {
            return nil
        }
        
        self.restaurantId = restaurantId
        self.restaurantName = data["restaurantName"] as? String ?? "Restaurant"
        self.userId = data["userId"] as? String ?? ""
        self.total = total
        self.subtotal = data["subtotal"] as? Double ?? 0.0
        self.deliveryFee = data["deliveryFee"] as? Double ?? 0.0
        self.deliveryOption = data["deliveryOption"] as? String ?? "Delivery"
        self.status = data["status"] as? String ?? "pending"
        self.orderStatus = data["order_status"] as? String ?? ""
        self.createdAt = data["createdAt"] as? TimeInterval ?? 0
        self.updatedAt = data["updatedAt"] as? TimeInterval ?? 0
        self.driverId = data["driverId"] as? String
        self.driverName = data["driverName"] as? String
        
        // Address handling
        if let addressData = data["address"] as? [String: Any] {
            let street = addressData["street"] as? String ?? ""
            let unit = addressData["unit"] as? String ?? ""
            let city = addressData["city"] as? String ?? ""
            let state = addressData["state"] as? String ?? ""
            let zipCode = addressData["zipCode"] as? String ?? ""
            
            var addressComponents: [String] = [street]
            
            if !unit.isEmpty {
                addressComponents.append("Unit \(unit)")
            }
            
            addressComponents.append("\(city), \(state) \(zipCode)")
            self.address = addressComponents.joined(separator: ", ")
        } else {
            self.address = "No address provided"
        }
        
        // Parse items
        if let itemsData = data["items"] as? [[String: Any]] {
            self.items = itemsData.compactMap { CustomerOrderItem(data: $0) }
        } else {
            self.items = []
        }
    }
}

struct CustomerOrderItem: Identifiable {
    let id: String
    let name: String
    let quantity: Int
    let price: Double
    let totalPrice: Double
    
    init?(data: [String: Any]) {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String,
              let quantity = data["quantity"] as? Int,
              let price = data["price"] as? Double else {
            return nil
        }
        
        self.id = id
        self.name = name
        self.quantity = quantity
        self.price = price
        self.totalPrice = price * Double(quantity)
    }
}
