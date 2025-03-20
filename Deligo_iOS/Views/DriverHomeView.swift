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

// Account tab view
struct DriverAccountView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Profile")) {
                    NavigationLink("Personal Information") {
                        Text("Personal Information View")
                    }
                    NavigationLink("Vehicle Information") {
                        Text("Vehicle Information View")
                    }
                }
                
                Section(header: Text("Earnings")) {
                    NavigationLink("Payment History") {
                        Text("Payment History View")
                    }
                    NavigationLink("Bank Details") {
                        Text("Bank Details View")
                    }
                }
                
                Section(header: Text("Support")) {
                    NavigationLink("Help Center") {
                        Text("Help Center View")
                    }
                    NavigationLink("Contact Support") {
                        DriverChatView(authViewModel: authViewModel)
                    }
                }
                
                Section {
                    Button(action: {
                        authViewModel.logout()
                    }) {
                        Text("Logout")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Account")
        }
    }
}

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