import SwiftUI
import FirebaseDatabase
import CoreLocation
import GoogleMaps

struct DriverMainView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            DriverHomeView(authViewModel: authViewModel)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            // Orders Tab
            DriverOrdersView(authViewModel: authViewModel)
                .tabItem {
                    Image(systemName: "list.bullet.rectangle.fill")
                    Text("Orders")
                }
                .tag(1)
            
            // Account Tab
            DriverAccountView(authViewModel: authViewModel)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Account")
                }
                .tag(2)
        }
        .accentColor(Color(hex: "F4A261"))
    }
}

struct DriverOrdersView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var currentOrders: [DeliveryOrder] = []
    @State private var pastOrders: [DeliveryOrder] = []
    @State private var isLoading = true
    let database = Database.database().reference()
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading orders...")
                } else if currentOrders.isEmpty && pastOrders.isEmpty {
                    Text("No orders found")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List {
                        if !currentOrders.isEmpty {
                            Section(header: Text("Current Orders")) {
                                ForEach(currentOrders) { order in
                                    NavigationLink(destination: DriverOrderDetailView(order: order)) {
                                        OrderRow(order: order)
                                    }
                                }
                            }
                        }
                        
                        if !pastOrders.isEmpty {
                            Section(header: Text("Past Orders")) {
                                ForEach(pastOrders) { order in
                                    NavigationLink(destination: DriverOrderDetailView(order: order)) {
                                        OrderRow(order: order)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Orders")
            .onAppear {
                loadOrders()
            }
        }
    }
    
    private func loadOrders() {
        guard let userId = authViewModel.currentUserId else { return }
        isLoading = true
        
        database.child("orders")
            .queryOrdered(byChild: "driverId")
            .queryEqual(toValue: userId)
            .observeSingleEvent(of: .value) { snapshot in
                var currentOrdersList: [DeliveryOrder] = []
                var pastOrdersList: [DeliveryOrder] = []
                
                for child in snapshot.children {
                    guard let orderSnapshot = child as? DataSnapshot,
                          let orderData = orderSnapshot.value as? [String: Any],
                          let order = DeliveryOrder(id: orderSnapshot.key, data: orderData) else {
                        continue
                    }
                    
                    let status = orderData["status"] as? String ?? ""
                    
                    if status == "delivered" || status == "cancelled" {
                        pastOrdersList.append(order)
                    } else {
                        currentOrdersList.append(order)
                    }
                }
                
                DispatchQueue.main.async {
                    self.currentOrders = currentOrdersList
                    self.pastOrders = pastOrdersList
                    self.isLoading = false
                }
            }
    }
}

struct OrderRow: View {
    let order: DeliveryOrder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Order #\(order.id.suffix(5))")
                .font(.headline)
            Text(order.address.formattedAddress)
                .font(.subheadline)
                .lineLimit(1)
            HStack {
                Text(order.status.capitalized)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(for: order.status))
                    .cornerRadius(4)
                Spacer()
                Text("$\(String(format: "%.2f", order.total))")
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "pending":
            return .orange
        case "accepted":
            return .blue
        case "in_progress":
            return .purple
        case "delivered":
            return .green
        case "cancelled":
            return .red
        default:
            return .gray
        }
    }
}

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
            print("⚠️ No user ID available")
            isLoading = false
            return
        }
        
        isLoading = true
        print("🔍 Starting to load orders for driver: \(userId)")
        
        // First, check for pending orders that aren't assigned to any driver
        database.child("orders")
            .queryOrdered(byChild: "status")
            .queryEqual(toValue: "pending")
            .observe(.value) { snapshot in
                print("📦 Found \(snapshot.childrenCount) pending orders")
                var orders: [DeliveryOrder] = []
                
                for child in snapshot.children {
                    guard let orderSnapshot = child as? DataSnapshot,
                          let orderData = orderSnapshot.value as? [String: Any] else {
                        print("❌ Failed to parse pending order data")
                        continue
                    }
                    
                    // Only consider orders that don't have a driver assigned
                    if orderData["driverId"] == nil {
                        guard let order = DeliveryOrder(id: orderSnapshot.key, data: orderData) else {
                            print("❌ Failed to create DeliveryOrder object for: \(orderSnapshot.key)")
                            continue
                        }
                        
                        print("✅ Adding pending order: \(order.id)")
                        orders.append(order)
                    }
                }
                
                // Update UI with pending orders
                DispatchQueue.main.async {
                    print("📱 Updating UI with \(orders.count) pending orders")
                    self.availableOrders = orders
                    self.isLoading = false
                }
            }
        
        // Then check for orders specifically assigned to this driver
        database.child("orders")
            .queryOrdered(byChild: "driverId")
            .queryEqual(toValue: userId)
            .observe(.value) { snapshot in
                print("🚗 Found \(snapshot.childrenCount) orders assigned to driver")
                
                for child in snapshot.children {
                    guard let orderSnapshot = child as? DataSnapshot,
                          let orderData = orderSnapshot.value as? [String: Any] else {
                        print("❌ Failed to parse assigned order data")
                        continue
                    }
                    
                    let status = orderData["status"] as? String ?? ""
                    let orderStatus = orderData["order_status"] as? String ?? ""
                    
                    print("📋 Processing order: \(orderSnapshot.key)")
                    print("Status: \(status), OrderStatus: \(orderStatus)")
                    
                    // If order is not delivered or cancelled
                    if status != "delivered" && status != "cancelled" {
                        guard let order = DeliveryOrder(id: orderSnapshot.key, data: orderData) else {
                            print("❌ Failed to create DeliveryOrder object")
                            continue
                        }
                        
                        // Check if this should be the active order
                        if (status == "in_progress" && orderStatus == "assigned_driver") ||
                           (status == "assigned_driver" && orderStatus == "pending_driver_acceptance") {
                            print("🎯 Setting active order: \(order.id)")
                            DispatchQueue.main.async {
                                self.activeOrder = order
                            }
                        }
                    }
                }
            }
        
        // Also check for orders with order_status="assigned_driver"
        database.child("orders")
            .queryOrdered(byChild: "order_status")
            .queryEqual(toValue: "assigned_driver")
            .observe(.value) { snapshot in
                print("🔄 Found \(snapshot.childrenCount) orders with status 'assigned_driver'")
                
                for child in snapshot.children {
                    guard let orderSnapshot = child as? DataSnapshot,
                          let orderData = orderSnapshot.value as? [String: Any] else {
                        print("❌ Failed to parse order with assigned_driver status")
                        continue
                    }
                    
                    // Only process if this order belongs to this driver or has no driver assigned
                    let orderDriverId = orderData["driverId"] as? String
                    if orderDriverId == nil || orderDriverId == userId {
                        guard let order = DeliveryOrder(id: orderSnapshot.key, data: orderData) else {
                            print("❌ Failed to create DeliveryOrder object")
                            continue
                        }
                        
                        print("✅ Found assigned order: \(order.id)")
                        // If no driver is assigned, assign it to this driver
                        if orderDriverId == nil {
                            print("🔄 Assigning order to driver: \(userId)")
                            database.child("orders").child(order.id).updateChildValues([
                                "driverId": userId,
                                "status": "in_progress",
                                "order_status": "assigned_driver"
                            ])
                        }
                        
                        // Update active order if not already set
                        DispatchQueue.main.async {
                            if self.activeOrder == nil {
                                print("🎯 Setting as active order: \(order.id)")
                                self.activeOrder = order
                            }
                        }
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
    @StateObject private var locationManager = DeliveryLocationManager.shared
    @State private var showingActionSheet = false
    @State private var restaurantName: String = "Loading..."
    @State private var restaurantAddress: String = "Loading..."
    @State private var customerName: String = "Loading..."
    @State private var restaurantLocation: CLLocationCoordinate2D?
    @State private var deliveryLocation: CLLocationCoordinate2D?
    let database = Database.database().reference()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Order Status Header
            HStack {
                Text("Order #\(order.id.prefix(8))")
                    .font(.headline)
                Spacer()
                Text("$\(String(format: "%.2f", order.total))")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            // Map View
            if let restaurantLoc = restaurantLocation,
               let deliveryLoc = deliveryLocation {
                DeliveryMapView(
                    driverLocation: locationManager.location?.coordinate,
                    restaurantLocation: restaurantLoc,
                    deliveryLocation: deliveryLoc,
                    restaurantName: restaurantName,
                    deliveryAddress: order.address.formattedAddress
                )
                .frame(height: 200)
                .cornerRadius(12)
            } else {
                ProgressView("Loading map...")
                    .frame(height: 200)
            }
            
            // Restaurant Details
            VStack(alignment: .leading, spacing: 4) {
                Text("Restaurant")
                    .font(.headline)
                Text(restaurantName)
                Text(restaurantAddress)
                    .foregroundColor(.gray)
            }
            
            // Delivery Details
            VStack(alignment: .leading, spacing: 4) {
                Text("Delivery Location")
                    .font(.headline)
                Text(order.address.formattedAddress)
                    .foregroundColor(.gray)
            }
            
            // Customer Details
            VStack(alignment: .leading, spacing: 4) {
                Text("Customer")
                    .font(.headline)
                Text(customerName)
                Text("Payment: \(order.paymentMethod)")
                    .foregroundColor(.gray)
            }
            
            // Action Buttons
            HStack(spacing: 16) {
                Button(action: onReject) {
                    Text("Reject Order")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    onAccept("accepted")
                }) {
                    Text("Accept Order")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 8)
        .onAppear {
            fetchRestaurantDetails()
            fetchCustomerDetails()
            geocodeAddresses()
        }
    }
    
    private func fetchRestaurantDetails() {
        database.child("restaurants").child(order.restaurantId).observeSingleEvent(of: .value) { snapshot in
            guard let data = snapshot.value as? [String: Any] else { return }
            
            if let storeInfo = data["store_info"] as? [String: Any],
               let name = storeInfo["name"] as? String,
               let address = storeInfo["address"] as? String {
                self.restaurantName = name
                self.restaurantAddress = address
                
                // Geocode the restaurant address
                let geocoder = CLGeocoder()
                geocoder.geocodeAddressString(address) { placemarks, error in
                    if let location = placemarks?.first?.location?.coordinate {
                        DispatchQueue.main.async {
                            self.restaurantLocation = location
                        }
                    }
                }
            }
        }
    }
    
    private func fetchCustomerDetails() {
        database.child("customers").child(order.userId).observeSingleEvent(of: .value) { snapshot in
            guard let data = snapshot.value as? [String: Any] else { return }
            
            if let fullName = data["fullName"] as? String {
                self.customerName = fullName
            }
        }
    }
    
    private func geocodeAddresses() {
        let geocoder = CLGeocoder()
        
        // Geocode delivery address
        geocoder.geocodeAddressString(order.address.formattedAddress) { placemarks, error in
            if let location = placemarks?.first?.location?.coordinate {
                DispatchQueue.main.async {
                    self.deliveryLocation = location
                }
            }
        }
    }
}

#Preview {
    DriverMainView(authViewModel: AuthViewModel())
} 
