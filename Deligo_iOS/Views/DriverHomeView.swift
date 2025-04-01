import SwiftUI
import FirebaseDatabase

struct DriverHomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DriverDashboardView(authViewModel: authViewModel)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            DriverOrdersView(authViewModel: authViewModel)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Orders")
                }
                .tag(1)
            
            DriverAccountView(authViewModel: authViewModel)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Account")
                }
                .tag(2)
        }
    }
}

// Main dashboard view (previously DriverHomeView content)
struct DriverDashboardView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var documentStatus: String = "not_submitted"
    @State private var isAvailable = false
    @State private var todaysDeliveries = 0
    @State private var todaysEarnings = 0.0
    @State private var availableOrders: [DeliveryOrder] = []
    @State private var activeOrder: DeliveryOrder? = nil
    @State private var isLoading = true
    private let database = Database.database().reference()
    
    var body: some View {
        Group {
            if documentStatus == "approved" {
                ScrollView {
                    VStack(spacing: 0) {
                        // Driver Status Section
                        VStack(spacing: 16) {
                            Text("Driver Status")
                                .font(.title2)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text(isAvailable ? "You are currently online" : "You are currently offline")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Available for Orders Toggle
                            HStack {
                                Text("Available for Orders")
                                    .font(.headline)
                                Spacer()
                                Toggle("", isOn: $isAvailable)
                                    .onChange(of: isAvailable) { _, newValue in
                                        updateDriverAvailability(newValue)
                                    }
                            }
                        }
                        .padding()
                        .background(Color.white)
                        
                        // Today's Stats Section
                        VStack(spacing: 16) {
                            Text("Today's Stats")
                                .font(.title2)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
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
                        
                        // Available Orders Section - now showing both available and active orders
                        VStack(spacing: 16) {
                            Text("All Orders")
                                .font(.title2)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if isLoading {
                                ProgressView("Loading orders...")
                            } else if availableOrders.isEmpty && activeOrder == nil {
                                Text("No orders available at the moment")
                                    .foregroundColor(.gray)
                            } else {
                                LazyVStack(spacing: 16) {
                                    // Show active order at the top if exists
                                    if let activeOrder = activeOrder {
                                        Text("Your Current Order")
                                            .font(.headline)
                                            .fontWeight(.medium)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 4)
                                        
                                        ActiveOrderCard(order: activeOrder, onUpdateStatus: { newStatus in
                                            updateOrderStatus(order: activeOrder, newStatus: newStatus)
                                        })
                                        .background(Color.white.opacity(0.6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.green, lineWidth: 2)
                                        )
                                        
                                        if !availableOrders.isEmpty {
                                            Text("Available Orders")
                                                .font(.headline)
                                                .fontWeight(.medium)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.top, 8)
                                                .padding(.horizontal, 4)
                                        }
                                    }
                                    
                                    // Then show available orders
                                    ForEach(availableOrders) { order in
                                        AvailableOrderCard(order: order, onAccept: {
                                            acceptOrder(order)
                                        })
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.white)
                    }
                }
                .background(Color(.systemGroupedBackground))
                .onAppear {
                    setupDriverStatusListener() // Use real-time listener instead
                    setupActiveOrderListener() // Use real-time listener for active order
                    loadTodaysStats()
                    loadAvailableOrders() // Always load available orders
                }
                .onDisappear {
                    // Remove any active listeners when view disappears
                    if let userId = authViewModel.currentUserId {
                        database.child("drivers").child(userId).removeAllObservers()
                        database.child("orders").removeAllObservers()
                    }
                }
            } else {
                DriverDocumentsView(authViewModel: authViewModel)
            }
        }
        .onAppear {
            checkDocumentStatus()
        }
    }
    
    private func checkDocumentStatus() {
        guard let userId = authViewModel.currentUserId else { return }
        
        database.child("drivers").child(userId).child("documents").child("status")
            .observeSingleEvent(of: .value) { snapshot in
                if let status = snapshot.value as? String {
                    self.documentStatus = status
                }
            }
    }
    
    private func setupDriverStatusListener() {
        guard let userId = authViewModel.currentUserId else { return }
        
        // Use observe instead of observeSingleEvent to get real-time updates
        database.child("drivers").child(userId).child("isAvailable")
            .observe(.value) { snapshot in
                if let isAvailable = snapshot.value as? Bool {
                    DispatchQueue.main.async {
                        self.isAvailable = isAvailable
                    }
                }
            }
    }
    
    private func setupActiveOrderListener() {
        guard let userId = authViewModel.currentUserId else { return }
        
        // Query orders assigned to this driver
        database.child("orders")
            .queryOrdered(byChild: "driverId")
            .queryEqual(toValue: userId)
            .observe(.value) { [self] snapshot in
                var foundActiveOrder = false
                
                for child in snapshot.children {
                    guard let orderSnapshot = child as? DataSnapshot,
                          let orderData = orderSnapshot.value as? [String: Any],
                          let order = DeliveryOrder(id: orderSnapshot.key, data: orderData) else {
                        continue
                    }
                    
                    let status = orderData["status"] as? String ?? ""
                    let orderStatus = orderData["order_status"] as? String ?? ""
                    print("Found order in active listener: \(order.id) with status: \(status) and orderStatus: \(orderStatus)")
                    
                    // Check if this is an active order (not delivered or cancelled)
                    if status != "delivered" && status != "cancelled" {
                        if status == "in_progress" && orderStatus == "assigned_driver" {
                            foundActiveOrder = true
                            print("Setting active order in listener: \(order.id)")
                            
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
    
    private func updateDriverAvailability(_ available: Bool) {
        guard let userId = authViewModel.currentUserId else { return }
        
        database.child("drivers").child(userId).updateChildValues([
            "isAvailable": available
        ]) { error, _ in
            if let error = error {
                print("Error updating availability: \(error.localizedDescription)")
            } else {
                loadAvailableOrders() // Always reload available orders
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
            .observeSingleEvent(of: .value) { snapshot in
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
            .observe(.value) { [self] snapshot in
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
                    .observe(.value) { [self] pendingSnapshot in
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
    let onUpdateStatus: (String) -> Void
    @State private var showingActionSheet = false
    
    // Helper to determine if driver has accepted the order yet
    private var isAccepted: Bool {
        // If status is still "assigned_driver", driver hasn't accepted yet
        return order.status != "assigned_driver"
    }
    
    // Helper to determine if action button should be shown
    private var hasAvailableAction: Bool {
        return order.status == "assigned_driver" || 
               order.status == "preparing" ||
               order.status == "ready_for_pickup" ||
               order.status == "picked_up"
    }
    
    // For simple cases where there's only one logical next status
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
    
    // Button text based on status
    private var actionButtonText: String {
        switch order.status {
        case "assigned_driver":
            return "ACCEPT ORDER"
        case "preparing", "ready_for_pickup": 
            return "Mark as Picked Up"
        case "picked_up":
            return "Mark as Delivered"
        default:
            return "Update Status"
        }
    }
    
    // Button color based on status
    private var actionButtonColor: Color {
        switch order.status {
        case "assigned_driver":
            return .green
        case "preparing", "ready_for_pickup":
            return .purple
        case "picked_up":
            return .orange
        default:
            return .gray
        }
    }
    
    private var statusColor: Color {
        switch order.status {
        case "assigned_driver":
            return .blue
        case "preparing":
            return .orange
        case "ready_for_pickup":
            return .purple
        case "picked_up":
            return .green
        case "delivered":
            return .gray
        default:
            return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Distinctive header for active order (different if not accepted yet)
            HStack {
                Spacer()
                Text(isAccepted ? "ACTIVE ORDER" : "NEW ORDER ASSIGNMENT")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isAccepted ? Color.green : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                Spacer()
            }
            .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Order #\(order.id.prefix(8))")
                        .font(.headline)
                    Spacer()
                    Text(formatPrice(order.total))
                        .font(.headline)
                }
                
                Text("Status: \(order.status.replacingOccurrences(of: "_", with: " ").capitalized)")
                    .font(.subheadline)
                    .foregroundColor(statusColor)
            }
            
            Divider()
            
            // Show accept/reject buttons for assigned orders
            if order.status == "assigned_driver" {
                HStack(spacing: 16) {
                    // Accept button
                    Button(action: {
                        onUpdateStatus("driver_accepted")
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Accept")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    // Reject button
                    Button(action: {
                        onUpdateStatus("rejected")
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Reject")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            } else if hasAvailableAction {
                // Show single action button for other statuses
                Button(action: {
                    if let nextStatus = directStatusTransition {
                        onUpdateStatus(nextStatus)
                    } else {
                        showingActionSheet = true
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text(actionButtonText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(actionButtonColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: price)) ?? "$\(String(format: "%.2f", price))"
    }
}

#Preview {
    DriverHomeView(authViewModel: AuthViewModel())
} 
