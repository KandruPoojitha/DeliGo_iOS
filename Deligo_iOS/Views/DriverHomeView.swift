import SwiftUI
import FirebaseDatabase

struct DriverHomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var ordersViewModel: DriverOrdersViewModel
    @State private var selectedOrder: DriverOrder?
    @State private var showingDeliveryTimeSheet = false
    @State private var estimatedMinutes: String = ""
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        self._ordersViewModel = StateObject(wrappedValue: DriverOrdersViewModel(driverId: authViewModel.currentUserId ?? ""))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if ordersViewModel.isLoading {
                    ProgressView()
                } else if ordersViewModel.assignedOrders.isEmpty {
                    EmptyOrdersView()
                } else {
                    OrdersList()
                }
            }
            .navigationTitle("Available Orders")
            .refreshable {
                ordersViewModel.loadAssignedOrders()
            }
            .alert("Error", isPresented: .constant(ordersViewModel.error != nil)) {
                Button("OK") {
                    ordersViewModel.error = nil
                }
            } message: {
                if let error = ordersViewModel.error {
                    Text(error)
                }
            }
        }
    }
    
    @ViewBuilder
    private func OrdersList() -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(ordersViewModel.assignedOrders) { order in
                    OrderCard(order: order)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    private func OrderCard(order: DriverOrder) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Order Header
            HStack {
                Text("#\(order.id.prefix(8))")
                    .font(.headline)
                Spacer()
                StatusBadge(status: getOrderStatus(from: order.status))
            }
            
            Divider()
            
            // Restaurant Info
            VStack(alignment: .leading, spacing: 4) {
                Text(order.restaurantName)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(order.restaurantAddress)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            // Delivery Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Delivery to:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(order.deliveryAddress)
                    .font(.subheadline)
            }
            
            // Order Items
            VStack(alignment: .leading, spacing: 8) {
                Text("Items:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
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
            
            Divider()
            
            // Total and Actions
            HStack {
                VStack(alignment: .leading) {
                    Text("Total")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("$\(String(format: "%.2f", order.total))")
                        .font(.headline)
                }
                
                Spacer()
                
                ActionButtons(order: order)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // Helper function to convert string status to OrderStatus enum
    private func getOrderStatus(from statusString: String) -> OrderStatus {
        return OrderStatus(rawValue: statusString) ?? .pending
    }
    
    private func StatusBadge(status: OrderStatus) -> some View {
        Text(status.displayText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: status.color).opacity(0.2))
            .foregroundColor(Color(hex: status.color))
            .cornerRadius(8)
    }
    
    @ViewBuilder
    private func ActionButtons(order: DriverOrder) -> some View {
        HStack(spacing: 8) {
            let orderStatus = getOrderStatus(from: order.status)
            
            switch orderStatus {
            case .pending:
                Button(action: {
                    ordersViewModel.updateOrderStatus(orderId: order.id, status: .accepted)
                }) {
                    Text("Accept")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                
            case .accepted:
                Button(action: {
                    ordersViewModel.updateOrderStatus(orderId: order.id, status: .pickedUp)
                }) {
                    Text("Picked Up")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.purple)
                        .cornerRadius(8)
                }
                
            case .pickedUp:
                Button(action: {
                    selectedOrder = order
                    showingDeliveryTimeSheet = true
                }) {
                    Text("Start Delivery")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(8)
                }
                
            case .delivering:
                Button(action: {
                    ordersViewModel.updateOrderStatus(orderId: order.id, status: .delivered)
                }) {
                    Text("Complete")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(8)
                }
                
            default:
                EmptyView()
            }
        }
        .sheet(isPresented: $showingDeliveryTimeSheet) {
            DeliveryTimeSheet(order: selectedOrder!, isPresented: $showingDeliveryTimeSheet, ordersViewModel: ordersViewModel)
        }
    }
}

struct EmptyOrdersView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cube.box")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No Orders Available")
                .font(.title2)
                .fontWeight(.medium)
            Text("New orders will appear here")
                .foregroundColor(.gray)
        }
    }
}

struct DeliveryTimeSheet: View {
    let order: DriverOrder
    @Binding var isPresented: Bool
    @ObservedObject var ordersViewModel: DriverOrdersViewModel
    @State private var estimatedMinutes: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Estimated Delivery Time")) {
                    TextField("Minutes", text: $estimatedMinutes)
                        .keyboardType(.numberPad)
                }
                
                Section {
                    Button("Start Delivery") {
                        if let minutes = Int(estimatedMinutes) {
                            ordersViewModel.estimateDeliveryTime(orderId: order.id, minutes: minutes)
                            ordersViewModel.updateOrderStatus(orderId: order.id, status: .delivering)
                            isPresented = false
                        }
                    }
                    .disabled(estimatedMinutes.isEmpty)
                }
            }
            .navigationTitle("Delivery Estimate")
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
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
    @State private var availableOrders: [Order] = []
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
                        
                        // Available Orders Section
                        VStack(spacing: 16) {
                            Text("Available Orders")
                                .font(.title2)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if isLoading {
                                ProgressView("Loading orders...")
                            } else if availableOrders.isEmpty {
                                Text("No available orders at the moment")
                                    .foregroundColor(.gray)
                            } else {
                                LazyVStack(spacing: 16) {
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
                    loadDriverStatus()
                    loadTodaysStats()
                    if isAvailable {
                        loadAvailableOrders()
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
    
    private func loadDriverStatus() {
        guard let userId = authViewModel.currentUserId else { return }
        
        database.child("drivers").child(userId).child("isAvailable")
            .observeSingleEvent(of: .value) { snapshot in
                if let isAvailable = snapshot.value as? Bool {
                    self.isAvailable = isAvailable
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
                if available {
                    loadAvailableOrders()
                } else {
                    availableOrders = []
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
        guard isAvailable else {
            availableOrders = []
            return
        }
        
        isLoading = true
        
        database.child("orders")
            .queryOrdered(byChild: "status")
            .queryEqual(toValue: "pending")
            .observeSingleEvent(of: .value) { snapshot in
                var orders: [Order] = []
                
                for child in snapshot.children {
                    guard let orderSnapshot = child as? DataSnapshot,
                          let orderData = orderSnapshot.value as? [String: Any],
                          let order = Order(id: orderSnapshot.key, data: orderData) else {
                        continue
                    }
                    orders.append(order)
                }
                
                DispatchQueue.main.async {
                    self.availableOrders = orders
                    self.isLoading = false
                }
            }
    }
    
    private func acceptOrder(_ order: Order) {
        guard let userId = authViewModel.currentUserId else { return }
        
        database.child("drivers").child(userId).observeSingleEvent(of: .value) { snapshot in
            guard let driverData = snapshot.value as? [String: Any] else { return }
            
            var driverName: String?
            if let userInfo = driverData["user_info"] as? [String: Any] {
                driverName = userInfo["fullName"] as? String
            }
            if driverName == nil {
                driverName = driverData["fullName"] as? String
            }
            if driverName == nil {
                if let firstName = driverData["firstName"] as? String,
                   let lastName = driverData["lastName"] as? String {
                    driverName = "\(firstName) \(lastName)"
                }
            }
            
            let finalDriverName = driverName ?? "Assigned Driver"
            
            let orderUpdates: [String: Any] = [
                "driverId": userId,
                "driverName": finalDriverName,
                "status": "assigned_driver",
                "order_status": "preparing",
                "updatedAt": ServerValue.timestamp()
            ]
            
            let driverUpdates: [String: Any] = [
                "isAvailable": false,
                "currentOrderId": order.id
            ]
            
            let updates = [
                "orders/\(order.id)": orderUpdates,
                "drivers/\(userId)": driverUpdates
            ]
            
            database.updateChildValues(updates) { error, _ in
                if let error = error {
                    print("Error accepting order: \(error.localizedDescription)")
                } else {
                    DispatchQueue.main.async {
                        self.availableOrders.removeAll { $0.id == order.id }
                        self.isAvailable = false
                    }
                }
            }
        }
    }
}

// Orders tab view
struct DriverOrdersView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedOrderType = 0
    @State private var currentOrders: [Order] = []
    @State private var pastOrders: [Order] = []
    @State private var isLoading = true
    
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
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Orders")
    }
}

// Note: DriverAccountView has been moved to its own file: DriverAccountView.swift

// Keep existing AvailableOrderCard struct
struct AvailableOrderCard: View {
    let order: Order
    let onAccept: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Order header
            HStack {
                Text("Order #\(order.id.prefix(8))")
                    .font(.headline)
                Spacer()
                Text("$\(String(format: "%.2f", order.total))")
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "F4A261"))
            }
            
            // Restaurant info
            Text("From: Restaurant Name")
                .font(.subheadline)
            
            // Delivery address
            if order.deliveryOption.lowercased() != "pickup" {
                Text("To: \(order.address.formattedAddress)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            // Accept button
            Button(action: onAccept) {
                Text("ACCEPT ORDER")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "F4A261"))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// Add a new card for driver's current and past orders
struct DriverOrderCard: View {
    let order: Order
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Order #\(order.id.prefix(8))")
                    .font(.headline)
                Spacer()
                Text(order.status.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
            
            Text("From: Restaurant Name")
                .font(.subheadline)
            
            if order.deliveryOption.lowercased() != "pickup" {
                Text("To: \(order.address.formattedAddress)")
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

#Preview {
    DriverHomeView(authViewModel: AuthViewModel())
} 