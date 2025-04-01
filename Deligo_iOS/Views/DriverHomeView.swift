import SwiftUI
import FirebaseDatabase

struct DriverHomeView: View {
    @StateObject private var viewModel = DriverHomeViewModel()
    @ObservedObject var authViewModel: AuthViewModel
    @State private var isLoading = false
    @State private var availableOrders: [DeliveryOrder] = []
    @State private var activeOrder: DeliveryOrder?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var todaysDeliveries = 0
    @State private var todaysEarnings = 0.0
    @State private var showingActionSheet = false
    let database = Database.database().reference()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Driver Status Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Driver Status")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("You are currently online")
                            .foregroundColor(.gray)
                        
                        Toggle("Available for Orders", isOn: $viewModel.isAvailable)
                            .tint(.green)
                            .onChange(of: viewModel.isAvailable) { _, newValue in
                                viewModel.updateDriverAvailability(newValue)
                            }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    
                    // Today's Stats Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Today's Stats")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 40) {
                            VStack {
                                Text("\(todaysDeliveries)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text("Deliveries")
                                    .foregroundColor(.gray)
                            }
                            
                            VStack {
                                Text("$\(String(format: "%.2f", todaysEarnings))")
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text("Earnings")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    
                    // All Orders Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("All Orders")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let activeOrder = activeOrder {
                            Text("Your Current Order")
                                .font(.headline)
                                .padding(.top)
                            
                            ActiveOrderCard(
                                order: activeOrder,
                                onAccept: { newStatus in
                                    viewModel.updateOrderStatus(orderId: activeOrder.id, status: .accepted)
                                },
                                onReject: {
                                    showingAlert = true
                                    alertMessage = "Are you sure you want to reject this order?"
                                }
                            )
                        }
                        
                        if availableOrders.isEmpty && activeOrder == nil {
                            Text("No orders available at the moment")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        }
                    }
                    .padding()
                }
                .padding()
            }
            .background(Color(.systemGray6))
            .navigationTitle("Home")
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Notice"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onAppear {
            setupActiveOrderListener()
            loadAvailableOrders()
            loadTodaysStats()
        }
    }
    
    private func setupActiveOrderListener() {
        guard let userId = authViewModel.currentUserId else { return }
        
        // Query orders assigned to this driver
        database.child("orders")
            .queryOrdered(byChild: "driverId")
            .queryEqual(toValue: userId)
            .observe(.value) { snapshot in
                var foundActiveOrder = false
                
                for child in snapshot.children {
                    guard let orderSnapshot = child as? DataSnapshot,
                          let orderData = orderSnapshot.value as? [String: Any],
                          let order = DeliveryOrder(id: orderSnapshot.key, data: orderData) else {
                        continue
                    }
                    
                    let status = orderData["status"] as? String ?? ""
                    let orderStatus = orderData["order_status"] as? String ?? ""
                    
                    // Check if this is an active order (not delivered or cancelled)
                    if status != "delivered" && status != "cancelled" {
                        if status == "in_progress" && orderStatus == "assigned_driver" {
                            foundActiveOrder = true
                            
                            // Set as active order
                            DispatchQueue.main.async {
                                self.activeOrder = order
                            }
                            break
                        }
                    }
                }
                
                // If no active order found, clear the activeOrder
                if !foundActiveOrder {
                    DispatchQueue.main.async {
                        self.activeOrder = nil
                    }
                }
            }
    }
    
    private func loadAvailableOrders() {
        guard let userId = authViewModel.currentUserId else {
            isLoading = false
            return
        }
        
        isLoading = true
        print("Loading orders for driver: \(userId)")
        
        // Remove any existing observers
        database.child("orders").removeAllObservers()
        
        // Query orders assigned to this driver
        database.child("orders")
            .queryOrdered(byChild: "driverId")
            .queryEqual(toValue: userId)
            .observe(.value) { snapshot in
                print("Checking orders assigned to driver: \(userId)")
                print("Found \(snapshot.childrenCount) orders for this driver")
                
                var orders: [DeliveryOrder] = []
                var foundActiveOrder = false
                
                for child in snapshot.children {
                    guard let orderSnapshot = child as? DataSnapshot,
                          let orderData = orderSnapshot.value as? [String: Any] else {
                        print("Failed to get order data from snapshot")
                        continue
                    }
                    
                    // Debug print all fields
                    print("Order data for \(orderSnapshot.key):")
                    print("userId: \(orderData["userId"] as? String ?? "missing")")
                    print("restaurantId: \(orderData["restaurantId"] as? String ?? "missing")")
                    print("restaurantName: \(orderData["restaurantName"] as? String ?? "missing")")
                    print("subtotal: \(orderData["subtotal"] as? Double ?? -1)")
                    print("total: \(orderData["total"] as? Double ?? -1)")
                    print("deliveryOption: \(orderData["deliveryOption"] as? String ?? "missing")")
                    print("paymentMethod: \(orderData["paymentMethod"] as? String ?? "missing")")
                    print("status: \(orderData["status"] as? String ?? "missing")")
                    
                    guard let order = DeliveryOrder(id: orderSnapshot.key, data: orderData) else {
                        print("Failed to create DeliveryOrder object")
                        continue
                    }
                    
                    let status = orderData["status"] as? String ?? ""
                    let orderStatus = orderData["order_status"] as? String ?? ""
                    print("Processing order: \(order.id)")
                    print("Status: \(status), OrderStatus: \(orderStatus)")
                    
                    // If order is not delivered or cancelled
                    if status != "delivered" && status != "cancelled" {
                        print("Order is active (not delivered/cancelled)")
                        
                        // Check both status combinations
                        if (status == "in_progress" && orderStatus == "assigned_driver") ||
                           (status == "assigned_driver" && orderStatus == "pending_driver_acceptance") {
                            print("Setting as active order: \(order.id)")
                            foundActiveOrder = true
                            DispatchQueue.main.async {
                                self.activeOrder = order
                            }
                        } else {
                            print("Adding to available orders: \(order.id)")
                            orders.append(order)
                        }
                    } else {
                        print("Order is completed or cancelled: \(order.id)")
                    }
                }
                
                // Then check for pending orders that aren't assigned to any driver
                database.child("orders")
                    .queryOrdered(byChild: "status")
                    .queryEqual(toValue: "pending")
                    .observe(.value) { pendingSnapshot in
                        print("Checking pending orders")
                        print("Found \(pendingSnapshot.childrenCount) pending orders")
                        
                        for child in pendingSnapshot.children {
                            guard let orderSnapshot = child as? DataSnapshot,
                                  let orderData = orderSnapshot.value as? [String: Any] else {
                                print("Failed to get pending order data from snapshot")
                                continue
                            }
                            
                            // Debug print all fields for pending orders
                            print("Pending order data for \(orderSnapshot.key):")
                            print("userId: \(orderData["userId"] as? String ?? "missing")")
                            print("restaurantId: \(orderData["restaurantId"] as? String ?? "missing")")
                            print("restaurantName: \(orderData["restaurantName"] as? String ?? "missing")")
                            print("subtotal: \(orderData["subtotal"] as? Double ?? -1)")
                            print("total: \(orderData["total"] as? Double ?? -1)")
                            print("deliveryOption: \(orderData["deliveryOption"] as? String ?? "missing")")
                            print("paymentMethod: \(orderData["paymentMethod"] as? String ?? "missing")")
                            print("status: \(orderData["status"] as? String ?? "missing")")
                            
                            guard let order = DeliveryOrder(id: orderSnapshot.key, data: orderData) else {
                                print("Failed to create DeliveryOrder object for pending order")
                                continue
                            }
                            
                            // Only add pending orders that aren't assigned to any driver
                            if orderData["driverId"] == nil {
                                print("Found unassigned pending order: \(order.id)")
                                orders.append(order)
                            } else {
                                print("Skipping assigned pending order: \(order.id)")
                            }
                        }
                        
                        // Sort orders by creation time (newest first)
                        orders.sort { $0.createdAt > $1.createdAt }
                        
                        DispatchQueue.main.async {
                            print("Updating UI with \(orders.count) available orders")
                            print("Active order status: \(self.activeOrder?.id ?? "none")")
                            self.availableOrders = orders
                            self.isLoading = false
                        }
                    }
            }
    }
    
    private func loadTodaysStats() {
        guard let userId = authViewModel.currentUserId else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)!
        
        let startTimestamp = startOfDay.timeIntervalSince1970
        let endTimestamp = endOfDay.timeIntervalSince1970
        
        database.child("orders")
            .queryOrdered(byChild: "driverId")
            .queryEqual(toValue: userId)
            .observe(.value) { snapshot in
                var deliveries = 0
                var earnings = 0.0
                
                for child in snapshot.children {
                    guard let orderSnapshot = child as? DataSnapshot,
                          let orderData = orderSnapshot.value as? [String: Any],
                          let status = orderData["status"] as? String,
                          let timestamp = orderData["updatedAt"] as? TimeInterval,
                          status == "delivered" &&
                          timestamp >= startTimestamp &&
                          timestamp <= endTimestamp else {
                        continue
                    }
                    
                    deliveries += 1
                    if let earning = orderData["driverEarnings"] as? Double {
                        earnings += earning
                    }
                }
                
                DispatchQueue.main.async {
                    self.todaysDeliveries = deliveries
                    self.todaysEarnings = earnings
                }
            }
    }
    
    private func acceptOrder(_ order: DeliveryOrder) {
        guard let userId = authViewModel.currentUserId else { return }
        guard let userName = authViewModel.fullName else { return }
        
        // Update Firebase with driver information
        let orderRef = database.child("orders").child(order.id)
        
        // Update order initial assignment info but don't change to preparing yet
        orderRef.updateChildValues([
            "driverId": userId,
            "driverName": userName,
            "status": "assigned_driver",
            "orderStatus": "pending_driver_acceptance" // Indicates driver is assigned but hasn't accepted yet
        ]) { error, _ in
            if let error = error {
                print("Error accepting order: \(error.localizedDescription)")
                return
            }
            
            // Update the driver's currentOrderId
            database.child("drivers").child(userId).updateChildValues([
                "currentOrderId": order.id
            ])
            
            // Remove from available orders
            DispatchQueue.main.async {
                self.availableOrders.removeAll { $0.id == order.id }
            }
        }
    }
    
    private func updateOrderStatus(order: DeliveryOrder, newStatus: String) {
        let orderRef = database.child("orders").child(order.id)
        
        // Different fields to update based on status
        var updates: [String: Any] = ["status": newStatus]
        
        if newStatus == "driver_accepted" {
            // When driver explicitly accepts the order
            updates["orderStatus"] = "driver_accepted"
            updates["acceptedTime"] = ServerValue.timestamp()
            
            // After accepting, set status to ready_for_pickup so driver can mark as picked up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                orderRef.updateChildValues([
                    "status": "ready_for_pickup",
                    "orderStatus": "ready_for_pickup"
                ])
            }
        } else if newStatus == "picked_up" {
            updates["orderStatus"] = "on_the_way"
            updates["pickedUpTime"] = ServerValue.timestamp()
        } else if newStatus == "delivered" {
            updates["orderStatus"] = "completed"
            updates["deliveredTime"] = ServerValue.timestamp()
            
            // Also clear the driver's currentOrderId when order is delivered
            if let userId = authViewModel.currentUserId {
                database.child("drivers").child(userId).updateChildValues([
                    "currentOrderId": NSNull()
                ])
            }
        }
        
        orderRef.updateChildValues(updates) { error, _ in
            if let error = error {
                print("Error updating order status: \(error.localizedDescription)")
            }
        }
    }
    
    private func rejectOrder(_ order: DeliveryOrder) {
        // Implement reject logic
        // You might want to show a confirmation alert before rejecting
        showingAlert = true
        alertMessage = "Are you sure you want to reject this order?"
        // Add actual rejection logic here
    }
}

// Orders tab view
struct DriverOrdersView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedOrderType = 0
    @State private var currentOrders: [DeliveryOrder] = []
    @State private var pastOrders: [DeliveryOrder] = []
    @State private var isLoading = true
    private let database = Database.database().reference()
    
    var body: some View {
        VStack(spacing: 0) {
            // Order type picker
            Picker("Order Type", selection: $selectedOrderType) {
                Text("Current").tag(0)
                Text("Past").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if isLoading {
                ProgressView("Loading orders...")
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(selectedOrderType == 0 ? currentOrders : pastOrders) { order in
                            DriverOrderCard(order: order)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Orders")
        .onAppear {
            loadDriverOrders()
        }
    }
    
    private func loadDriverOrders() {
        guard let driverId = authViewModel.currentUserId else { 
            isLoading = false
            return 
        }
        
        isLoading = true
        
        // Remove any existing observers
        database.child("orders").removeAllObservers()
        
        // Real-time listener for orders assigned to this driver
        database.child("orders")
            .queryOrdered(byChild: "driverId")
            .queryEqual(toValue: driverId)
            .observe(.value, with: { [self] snapshot in
                var current: [DeliveryOrder] = []
                var past: [DeliveryOrder] = []
                
                for child in snapshot.children {
                    guard let orderSnapshot = child as? DataSnapshot,
                          let orderData = orderSnapshot.value as? [String: Any],
                          let order = DeliveryOrder(id: orderSnapshot.key, data: orderData),
                          let status = orderData["status"] as? String else {
                        continue
                    }
                    
                    // Sort orders into current and past based on status
                    if status == "delivered" || status == "cancelled" {
                        past.append(order)
                    } else {
                        current.append(order)
                    }
                }
                
                // Also look for orders with order_status="assigned_driver"
                self.database.child("orders")
                    .queryOrdered(byChild: "order_status")
                    .queryEqual(toValue: "assigned_driver")
                    .observeSingleEvent(of: .value) { [self] assignedSnapshot in
                        for child in assignedSnapshot.children {
                            guard let orderSnapshot = child as? DataSnapshot,
                                  let orderData = orderSnapshot.value as? [String: Any],
                                  let order = DeliveryOrder(id: orderSnapshot.key, data: orderData) else {
                                continue
                            }
                            
                            // Only add if not already in the list and doesn't have a different driver ID
                            let orderId = orderSnapshot.key
                            let orderDriverId = orderData["driverId"] as? String
                            
                            // If no driver ID or matches this driver, and not already in list
                            if (orderDriverId == nil || orderDriverId == driverId) && 
                               !current.contains(where: { $0.id == orderId }) {
                                current.append(order)
                                
                                // Update order with this driver's ID if not set
                                if orderDriverId == nil {
                                    database.child("orders").child(orderId).updateChildValues([
                                        "driverId": driverId,
                                        "status": "in_progress",
                                        "order_status": "assigned_driver"
                                    ])
                                }
                            }
                        }
                
                        // Sort orders by created timestamp (newest first)
                        current.sort { $0.createdAt > $1.createdAt }
                        past.sort { $0.createdAt > $1.createdAt }
                        
                        DispatchQueue.main.async {
                            self.currentOrders = current
                            self.pastOrders = past
                            self.isLoading = false
                        }
                    }
            }) { error in
                print("Error loading driver orders: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
    }
}

// Note: DriverAccountView has been moved to its own file: DriverAccountView.swift

// Card for available orders that the driver can choose to accept
struct AvailableOrderCard: View {
    let order: DeliveryOrder
    let onAccept: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Order header with restaurant and customer info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Order #\(order.id.prefix(8))")
                        .font(.headline)
                    Spacer()
                    Text(formatPrice(order.total))
                        .font(.headline)
                }
                
                Text("From Restaurant: \(order.restaurantId.prefix(8))")
                    .font(.subheadline)
            }
            
            Divider()
            
            // Order items summary
            Text("\(order.items.count) items")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            ForEach(order.items.prefix(3)) { item in
                HStack {
                    Text("\(item.quantity)x \(item.name)")
                        .font(.subheadline)
                    Spacer()
                    Text(formatPrice(item.totalPrice))
                        .font(.subheadline)
                }
            }
            
            if order.items.count > 3 {
                Text("+ \(order.items.count - 3) more items...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Divider()
            
            // Delivery address
            VStack(alignment: .leading, spacing: 4) {
                Text("Delivery to:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(order.address.streetAddress)")
                    .font(.subheadline)
                Text("\(order.address.city), \(order.address.state) \(order.address.zipCode)")
                    .font(.subheadline)
            }
            
            // Distance and estimated time (placeholder)
            HStack {
                Image(systemName: "location.circle")
                    .foregroundColor(.blue)
                Text("~3.2 miles away")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                Text("Est. 15-20 min")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.top, 4)
            
            // Accept button
            Button(action: onAccept) {
                Text("ACCEPT ORDER")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func formatPrice(_ price: Double) -> String {
        return "$\(String(format: "%.2f", price))"
    }
}

// Add a new card for driver's current and past orders
struct DriverOrderCard: View {
    let order: DeliveryOrder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Order #\(order.id.prefix(8))")
                    .font(.headline)
                Spacer()
                Text(order.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
            
            Text("From Restaurant: \(order.restaurantId.prefix(8))")
                .font(.subheadline)
            
            if order.deliveryOption.lowercased() != "pickup" {
                Text("To: \(order.address.streetAddress), \(order.address.city)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            HStack {
                Text("Total:")
                    .font(.subheadline)
                Spacer()
                Text("$\(String(format: "%.2f", order.total))")
                    .font(.headline)
                    .foregroundColor(Color(hex: "F4A261"))
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var statusColor: Color {
        switch order.status.lowercased() {
        case "preparing":
            return .blue
        case "picked_up":
            return .orange
        case "delivered":
            return .green
        default:
            return .gray
        }
    }
}

// Active order card - displays order that driver is currently working on
struct ActiveOrderCard: View {
    let order: DeliveryOrder
    let onAccept: (String) -> Void
    let onReject: () -> Void
    @State private var showingActionSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("ACTIVE ORDER")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .cornerRadius(8)
                
                Spacer()
                
                Text("$\(String(format: "%.2f", order.total))")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            // Order ID and Status
            VStack(alignment: .leading, spacing: 4) {
                Text("Order #\(order.id.prefix(8))")
                    .font(.headline)
                Text("Status: \(order.status.capitalized)")
                    .foregroundColor(.gray)
            }
            
            // Customer Details
            VStack(alignment: .leading, spacing: 8) {
                Text("Customer Details")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Text("Name: \(order.userId)")  // Replace with actual customer name when available
                Text("Payment: \(order.paymentMethod)")
            }
            
            // Restaurant Details
            VStack(alignment: .leading, spacing: 8) {
                Text("Restaurant Details")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Text("ID: \(order.restaurantId)")
                if let name = order.restaurantName {
                    Text("Name: \(name)")
                }
                // Add restaurant address when available
            }
            
            // Delivery Address
            VStack(alignment: .leading, spacing: 8) {
                Text("Delivery Address")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Text(order.address.formattedAddress)
                if let instructions = order.address.instructions {
                    Text("Instructions: \(instructions)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            // Order Items
            VStack(alignment: .leading, spacing: 8) {
                Text("Order Items")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                ForEach(order.items) { item in
                    HStack {
                        Text("\(item.quantity)x")
                            .foregroundColor(.gray)
                        Text(item.name)
                        Spacer()
                        Text("$\(String(format: "%.2f", item.totalPrice))")
                    }
                    if let instructions = item.specialInstructions {
                        Text("Note: \(instructions)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.leading)
                    }
                }
            }
            
            // Price Breakdown
            VStack(alignment: .leading, spacing: 8) {
                Text("Price Details")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                HStack {
                    Text("Subtotal")
                    Spacer()
                    Text("$\(String(format: "%.2f", order.subtotal))")
                }
                HStack {
                    Text("Delivery Fee")
                    Spacer()
                    Text("$\(String(format: "%.2f", order.deliveryFee))")
                }
                HStack {
                    Text("Tip")
                    Spacer()
                    Text("$\(String(format: "%.2f", order.tipAmount))")
                }
                Divider()
                HStack {
                    Text("Total")
                        .fontWeight(.bold)
                    Spacer()
                    Text("$\(String(format: "%.2f", order.total))")
                        .fontWeight(.bold)
                }
            }
            
            // Action Buttons
            HStack(spacing: 16) {
                Button(action: onReject) {
                    Text("Reject")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    if let nextStatus = directStatusTransition {
                        onAccept(nextStatus)
                    } else {
                        showingActionSheet = true
                    }
                }) {
                    Text("Accept")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                }
            }
            .padding(.top)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 8)
    }
    
    private var directStatusTransition: String? {
        switch order.status {
        case "assigned_driver":
            return nil // No direct transition, needs accept/reject buttons
        case "preparing", "ready_for_pickup":
            return "picked_up"
        case "picked_up":
            return "delivered"
        default:
            return nil
        }
    }
}

#Preview {
    DriverHomeView(authViewModel: AuthViewModel())
} 
