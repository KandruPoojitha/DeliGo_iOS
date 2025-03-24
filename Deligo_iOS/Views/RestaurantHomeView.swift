import SwiftUI
import FirebaseDatabase
import CoreLocation

struct RestaurantHomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    @State private var selectedOrderTab = 0
    @State private var isRestaurantOpen = false
    @State private var restaurant: Restaurant?
    private let database = Database.database().reference()
    
    var body: some View {
        Group {
            switch authViewModel.documentStatus {
            case .notSubmitted:
                RestaurantDocumentUploadView(authViewModel: authViewModel)
            case .pending:
                VStack(spacing: 20) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "F4A261"))
                    
                    Text("Documents Under Review")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Your documents are being reviewed by our team. This process usually takes 1-2 business days.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                }
                .padding()
            case .approved:
                if let restaurant = restaurant {
                    TabView(selection: $selectedTab) {
                        // Orders Tab
                        OrdersTabView(selectedOrderTab: $selectedOrderTab, 
                                    isRestaurantOpen: $isRestaurantOpen,
                                    authViewModel: authViewModel)
                            .tabItem {
                                Image(systemName: "list.bullet")
                                Text("Orders")
                            }
                            .tag(0)
                        
                        // Menu Tab
                        RestaurantMenuView(restaurant: restaurant, authViewModel: authViewModel)
                            .tabItem {
                                Image(systemName: "menucard")
                                Text("Menu")
                            }
                            .tag(1)
                        
                        // Account Tab
                        RestaurantAccountView(authViewModel: authViewModel)
                            .tabItem {
                                Image(systemName: "person")
                                Text("Account")
                            }
                            .tag(2)
                    }
                } else {
                    ProgressView("Loading restaurant data...")
                        .onAppear {
                            loadRestaurantData()
                        }
                }
            case .rejected:
                VStack(spacing: 20) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("Documents Rejected")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Your documents have been rejected. Please review the requirements and submit again.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    Button(action: {
                        // Reset document status to notSubmitted
                        if let userId = authViewModel.currentUserId {
                            database.child("restaurants").child(userId).child("documents").updateChildValues([
                                "status": "notSubmitted"
                            ])
                        }
                    }) {
                        Text("Submit Again")
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(Color(hex: "F4A261"))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            // Set up real-time listener for isOpen status
            if let userId = authViewModel.currentUserId {
                database.child("restaurants").child(userId).child("isOpen").observe(.value) { snapshot in
                    if let isOpen = snapshot.value as? Bool {
                        DispatchQueue.main.async {
                            self.isRestaurantOpen = isOpen
                        }
                    }
                }
            }
        }
        .onChange(of: isRestaurantOpen) { oldValue, newValue in
            updateRestaurantStatus(isOpen: newValue)
        }
    }
    
    private func loadRestaurantData() {
        guard let userId = authViewModel.currentUserId else { return }
        let db = Database.database().reference()
        
        db.child("restaurants").child(userId).observeSingleEvent(of: .value) { snapshot in
            guard let dict = snapshot.value as? [String: Any],
                  let storeInfo = dict["store_info"] as? [String: Any] else {
                print("DEBUG: Failed to load restaurant data")
                return
            }
            
            // Get the current isOpen status
            if let isOpen = dict["isOpen"] as? Bool {
                DispatchQueue.main.async {
                    self.isRestaurantOpen = isOpen
                }
            }
            
            self.restaurant = Restaurant(
                id: userId,
                name: storeInfo["name"] as? String ?? "",
                description: storeInfo["description"] as? String ?? "",
                email: storeInfo["email"] as? String ?? "",
                phone: storeInfo["phone"] as? String ?? "",
                cuisine: storeInfo["cuisine"] as? String ?? "Various",
                priceRange: storeInfo["priceRange"] as? String ?? "$",
                rating: dict["rating"] as? Double ?? 0.0,
                numberOfRatings: dict["numberOfRatings"] as? Int ?? 0,
                address: storeInfo["address"] as? String ?? "",
                imageURL: storeInfo["imageURL"] as? String,
                isOpen: dict["isOpen"] as? Bool ?? false,
                latitude: (dict["location"] as? [String: Any])?["latitude"] as? Double ?? 0,
                longitude: (dict["location"] as? [String: Any])?["longitude"] as? Double ?? 0,
                distance: nil
            )
            print("DEBUG: Successfully loaded restaurant data")
        }
    }
    
    private func updateRestaurantStatus(isOpen: Bool) {
        guard let userId = authViewModel.currentUserId else { return }
        
        print("DEBUG: Updating restaurant status to: \(isOpen)")
        
        database.child("restaurants").child(userId).updateChildValues([
            "isOpen": isOpen
        ]) { error, _ in
            if let error = error {
                print("Error updating restaurant status: \(error.localizedDescription)")
            } else {
                print("DEBUG: Successfully updated restaurant status")
            }
        }
    }
}

struct OrdersTabView: View {
    @Binding var selectedOrderTab: Int
    @Binding var isRestaurantOpen: Bool
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject private var appSettings = AppSettings.shared
    @State private var hasVerifiedConnection = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header with Logo and Toggle
                HStack {
                    Image("deligo_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                    Spacer()
                    Text(isRestaurantOpen ? "Open" : "Closed")
                        .foregroundColor(isRestaurantOpen ? .green : .red)
                        .font(.headline)
                        .padding(.trailing, 8)
                    
                    // Restaurant Open/Close Toggle
                    Toggle("", isOn: $isRestaurantOpen)
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "F4A261")))
                        .frame(width: 51) // Standard iOS toggle width
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .padding(.top, geometry.safeAreaInsets.top)
                .background(appSettings.isDarkMode ? Color.black : Color.white)
                
                // Order Status Tabs
                HStack(spacing: 0) {
                    OrderTabButton(title: "New Orders", isSelected: selectedOrderTab == 0) {
                        selectedOrderTab = 0
                    }
                    
                    OrderTabButton(title: "In Progress", isSelected: selectedOrderTab == 1) {
                        selectedOrderTab = 1
                    }
                    
                    OrderTabButton(title: "Delivered", isSelected: selectedOrderTab == 2) {
                        selectedOrderTab = 2
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .background(appSettings.isDarkMode ? Color.black : Color.white)
                
                // Content based on selected tab
                TabView(selection: $selectedOrderTab) {
                    NewOrdersView(authViewModel: authViewModel)
                        .tag(0)
                    
                    InProgressOrdersView(authViewModel: authViewModel)
                        .tag(1)
                    
                    DeliveredOrdersView(authViewModel: authViewModel)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                Spacer()
            }
            .background(appSettings.isDarkMode ? Color.black : Color(.systemGroupedBackground))
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                if !hasVerifiedConnection {
                    verifyFirebaseConnection()
                    checkOrderData()
                    checkSpecificOrder("B46CA690-9DB0-43F3-97B4-0279CCEED7B1") // Check specific order ID from screenshot
                }
                
                // Listen for order status changes
                NotificationCenter.default.addObserver(
                    forName: Notification.Name("OrderStatusChanged"),
                    object: nil,
                    queue: .main
                ) { notification in
                    if let userInfo = notification.userInfo,
                       let orderId = userInfo["orderId"] as? String {
                        
                        print("DEBUG: 🔔 OrdersTabView received notification for order: \(orderId)")
                        
                        // If the notification includes the status and order_status, use them directly
                        if let newStatus = userInfo["newStatus"] as? String,
                           let newOrderStatus = userInfo["newOrderStatus"] as? String {
                            
                            print("DEBUG: 📊 Notification contains status=\(newStatus), order_status=\(newOrderStatus)")
                            
                            // Switch to the appropriate tab based on the status
                            DispatchQueue.main.async {
                                if (newStatus == "in_progress" && newOrderStatus == "accepted") {
                                    // Switch to the in-progress tab for in_progress/accepted orders
                                    if selectedOrderTab != 1 {
                                        print("DEBUG: 🔄 Switching to In Progress tab for accepted order")
                                        selectedOrderTab = 1
                                    }
                                } else if newStatus == "delivered" {
                                    // Switch to the delivered tab for delivered orders
                                    if selectedOrderTab != 2 {
                                        print("DEBUG: 🔄 Switching to Delivered tab for delivered order")
                                        selectedOrderTab = 2
                                    }
                                }
                            }
                        } else {
                            // No direct status info, query Firebase
                            let database = Database.database().reference()
                            database.child("orders").child(orderId).observeSingleEvent(of: .value) { snapshot in
                                if let dict = snapshot.value as? [String: Any],
                                   let status = dict["status"] as? String {
                                    
                                    let orderStatus = dict["order_status"] as? String ?? ""
                                    print("DEBUG: 🔍 Fetched status=\(status), order_status=\(orderStatus) for order \(orderId)")
                                    
                                    DispatchQueue.main.async {
                                        // Switch to the appropriate tab based on the status
                                        switch status.lowercased() {
                                        case "in_progress":
                                            // For in_progress, also check order_status
                                            if orderStatus.lowercased() == "accepted" {
                                                // Only switch if we're not already on the in-progress tab
                                                if selectedOrderTab != 1 {
                                                    print("DEBUG: 🔄 Switching to In Progress tab due to order status change")
                                                    selectedOrderTab = 1
                                                }
                                            }
                                        case "preparing", "assigned_driver":
                                            // Only switch if we're not already on the in-progress tab
                                            if selectedOrderTab != 1 {
                                                print("DEBUG: 🔄 Switching to In Progress tab due to order status change")
                                                selectedOrderTab = 1
                                            }
                                        case "delivered":
                                            // Only switch if we're not already on the delivered tab
                                            if selectedOrderTab != 2 {
                                                print("DEBUG: 🔄 Switching to Delivered tab due to order status change")
                                                selectedOrderTab = 2
                                            }
                                        default:
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self)
            }
        }
    }
    
    private func verifyFirebaseConnection() {
        print("DEBUG: Verifying Firebase connection")
        hasVerifiedConnection = true
        
        let database = Database.database().reference()
        
        // Check if we can access the database
        database.child(".info/connected").observe(.value) { snapshot in
            if let connected = snapshot.value as? Bool, connected {
                print("DEBUG: Connected to Firebase")
                
                // Check for number of orders in the database
                database.child("orders").observeSingleEvent(of: .value) { ordersSnapshot in
                    print("DEBUG: Total orders in database: \(ordersSnapshot.childrenCount)")
                    
                    // If we have the restaurant ID, check for its orders
                    if let restaurantId = authViewModel.currentUserId {
                        database.child("orders")
                            .queryOrdered(byChild: "restaurantId")
                            .queryEqual(toValue: restaurantId)
                            .observeSingleEvent(of: .value) { restaurantOrdersSnapshot in
                                print("DEBUG: Found \(restaurantOrdersSnapshot.childrenCount) orders for restaurant \(restaurantId)")
                                
                                // Count orders by status
                                var pendingCount = 0
                                var preparingCount = 0
                                var deliveredCount = 0
                                
                                for child in restaurantOrdersSnapshot.children {
                                    guard let snapshot = child as? DataSnapshot,
                                          let dict = snapshot.value as? [String: Any],
                                          let status = dict["status"] as? String else { continue }
                                    
                                    switch status {
                                    case "pending": pendingCount += 1
                                    case "preparing": preparingCount += 1
                                    case "delivered": deliveredCount += 1
                                    default: break
                                    }
                                }
                                
                                print("DEBUG: Order counts - Pending: \(pendingCount), Preparing: \(preparingCount), Delivered: \(deliveredCount)")
                            }
                    }
                }
            } else {
                print("DEBUG: Not connected to Firebase")
            }
        }
    }
    
    private func checkOrderData() {
        let database = Database.database().reference()
        
        // Get all orders to inspect their structure
        database.child("orders").observeSingleEvent(of: .value) { snapshot in
            print("\n\n📋 DETAILED ORDER INSPECTION 📋")
            print("Found \(snapshot.childrenCount) total orders")
            
            for child in snapshot.children {
                guard let snapshot = child as? DataSnapshot,
                      let dict = snapshot.value as? [String: Any] else { continue }
                
                let orderId = snapshot.key
                let status = dict["status"] as? String ?? "none"
                let restaurantId = dict["restaurantId"] as? String ?? "none"
                let customerId = dict["customerId"] as? String ?? "none"
                
                print("\n📦 ORDER: \(orderId)")
                print("  Status: '\(status)'")
                print("  Restaurant ID: '\(restaurantId)'")
                print("  Customer ID: '\(customerId)'")
                
                // If customer ID exists, look it up
                if customerId != "none" {
                    lookupCustomerDetails(customerId)
                }
                
                if let items = dict["items"] as? [[String: Any]] {
                    print("  Items: \(items.count)")
                    for (index, item) in items.enumerated() {
                        let name = item["name"] as? String ?? "Unknown"
                        let quantity = item["quantity"] as? Int ?? 0
                        print("    \(index+1). \(quantity)x \(name)")
                    }
                }
                
                // If this order belongs to the current restaurant
                if restaurantId == authViewModel.currentUserId {
                    print("  ✅ THIS ORDER BELONGS TO CURRENT RESTAURANT")
                    if status.lowercased() == "pending" {
                        print("  ✅ THIS ORDER SHOULD APPEAR IN NEW ORDERS TAB")
                    }
                }
            }
            print("\n\n")
        }
    }
    
    private func lookupCustomerDetails(_ customerId: String) {
        let database = Database.database().reference()
        
        print("\n🔍 LOOKING UP CUSTOMER: \(customerId)")
        
        database.child("customers").child(customerId).observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                print("✅ Customer exists in database")
                
                if let userData = snapshot.value as? [String: Any] {
                    // Print all values in the customer record for debugging
                    print("📋 Customer data:")
                    for (key, value) in userData {
                        print("  \(key): \(value)")
                    }
                    
                    // Specifically look for fullName field
                    if let fullName = userData["fullName"] as? String {
                        print("📋 Found fullName: \(fullName)")
                    } else {
                        print("❌ No fullName field found")
                    }
                }
            } else {
                print("❌ Customer with ID: \(customerId) does not exist")
            }
            
            // Also check the specific fullName path
            database.child("customers").child(customerId).child("fullName").observeSingleEvent(of: .value) { nameSnapshot in
                if nameSnapshot.exists() {
                    print("📋 Direct fullName check: \(nameSnapshot.value ?? "nil")")
                } else {
                    print("❌ No direct fullName field found")
                }
            }
        }
    }
    
    // Add a new function to check a specific order
    private func checkSpecificOrder(_ orderId: String) {
        let database = Database.database().reference()
        
        database.child("orders").child(orderId).observeSingleEvent(of: .value) { snapshot in
            print("\n🔍 CHECKING SPECIFIC ORDER: \(orderId)")
            
            guard let dict = snapshot.value as? [String: Any] else {
                print("❌ Order not found or not in correct format")
                return
            }
            
            let status = dict["status"] as? String ?? "unknown"
            let restaurantId = dict["restaurantId"] as? String ?? "unknown"
            let customerId = dict["customerId"] as? String ?? "unknown"
            let userId = dict["userId"] as? String ?? "unknown"
            let currentUserId = authViewModel.currentUserId ?? "not set"
            
            print("📋 Order Status: '\(status)'")
            print("📋 Order Restaurant ID: '\(restaurantId)'")
            print("📋 Order Customer ID: '\(customerId)'")
            print("📋 Order User ID: '\(userId)'")
            print("📋 Current User ID: '\(currentUserId)'")
            print("📋 Restaurant IDs Match: \(restaurantId == currentUserId)")
            
            // Look up customer information if available
            if customerId != "unknown" {
                print("📋 Looking up customer info for ID: \(customerId)")
                lookupCustomerDetails(customerId)
            }
            
            // Also try with userId if different
            if userId != "unknown" && userId != customerId {
                print("📋 Looking up user info for ID: \(userId)")
                lookupUserInfo(userId: userId)
            }
            
            print("\n")
        }
    }
    
    // Function to directly fetch a user's information from Firebase
    func lookupUserInfo(userId: String) {
        let database = Database.database().reference()
        
        print("\n🔍 LOOKING UP USER BY ID: \(userId)")
        
        database.child("users").child(userId).observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                print("✅ User document exists at users/\(userId)")
                
                if let userData = snapshot.value as? [String: Any] {
                    // Print all user data for debugging
                    print("📋 User data from users collection:")
                    for (key, value) in userData {
                        print("  \(key): \(value)")
                    }
                }
            } else {
                print("❌ User document does not exist at users/\(userId)")
            }
        }
        
        // Also check in the customers node
        database.child("customers").child(userId).observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                print("✅ User document exists at customers/\(userId)")
                
                if let userData = snapshot.value as? [String: Any] {
                    print("📋 Customer data:")
                    for (key, value) in userData {
                        print("  \(key): \(value)")
                    }
                    
                    // Look for important fields
                    let fullName = userData["fullName"] as? String
                    let email = userData["email"] as? String
                    let phone = userData["phone"] as? String
                    
                    print("📋 Key user data - Name: \(fullName ?? "nil"), Email: \(email ?? "nil"), Phone: \(phone ?? "nil")")
                }
            } else {
                print("❌ User document does not exist at customers/\(userId)")
            }
        }
    }
}

struct OrderTabButton: View {
    @ObservedObject private var appSettings = AppSettings.shared
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : (appSettings.isDarkMode ? .white : .black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color(hex: "F4A261") : Color.clear)
                .cornerRadius(25)
        }
    }
}

struct NewOrdersView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var orders: [Order] = []
    @State private var isLoading = false
    @State private var customerNames: [String: String] = [:] // To store updated customer names
    @State private var customerPhones: [String: String] = [:] // To store updated customer phones
    private let database = Database.database().reference()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if isLoading {
                    ProgressView("Loading orders...")
                        .padding(.top, 50)
                } else if orders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "square.stack.3d.up.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Orders Yet")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("New orders will appear here")
                            .foregroundColor(.gray)
                            
                        Button(action: {
                            refreshOrders()
                        }) {
                            Text("Refresh Orders")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(Color(hex: "F4A261"))
                                .cornerRadius(8)
                        }
                        .padding(.top, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else {
                    ForEach(orders) { order in
                        OrderCard(
                            order: order,
                            customerName: customerNames[order.id] ?? order.customerName,
                            customerPhone: customerPhones[order.id],
                            onAccept: {
                                acceptOrder(order)
                            }, 
                            onReject: {
                                rejectOrder(order)
                            }
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            refreshOrders()
        }
        .onAppear {
            refreshOrders()
            // Listen for customer info updates
            NotificationCenter.default.addObserver(
                forName: Notification.Name("CustomerInfoUpdated"),
                object: nil,
                queue: .main
            ) { notification in
                if let userInfo = notification.userInfo,
                   let orderId = userInfo["orderId"] as? String {
                    if let name = userInfo["customerName"] as? String {
                        customerNames[orderId] = name
                    }
                    if let phone = userInfo["customerPhone"] as? String {
                        customerPhones[orderId] = phone
                    }
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    private func refreshOrders() {
        isLoading = true
        loadNewOrders()
        // Add a minimum delay to make the loading state visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
        }
    }
    
    private func fetchCustomerNames() {
        print("DEBUG: Fetching customer info for \(orders.count) orders")
        let database = Database.database().reference()
        
        for order in orders {
            // Try with customerId first
            if !order.customerId.isEmpty {
                // Fetch both name and phone
                database.child("customers").child(order.customerId).observeSingleEvent(of: .value) { snapshot in
                    if let userData = snapshot.value as? [String: Any] {
                        // Handle name
                        if let fullName = userData["fullName"] as? String, !fullName.isEmpty {
                            DispatchQueue.main.async {
                                self.customerNames[order.id] = fullName
                            }
                        }
                        
                        // Handle phone
                        if let phone = userData["phone"] as? String, !phone.isEmpty {
                            DispatchQueue.main.async {
                                self.customerPhones[order.id] = phone
                            }
                        }
                    }
                }
            }
            
            // Also check users collection with userId if available
            database.child("orders").child(order.id).child("userId").observeSingleEvent(of: .value) { snapshot in
                if let userId = snapshot.value as? String, !userId.isEmpty {
                    // Try in users collection
                    database.child("users").child(userId).observeSingleEvent(of: .value) { userSnapshot in
                        if let userData = userSnapshot.value as? [String: Any] {
                            if let fullName = userData["fullName"] as? String, !fullName.isEmpty {
                                DispatchQueue.main.async {
                                    self.customerNames[order.id] = fullName
                                }
                            }
                            
                            if let phone = userData["phone"] as? String, !phone.isEmpty {
                                DispatchQueue.main.async {
                                    self.customerPhones[order.id] = phone
                                }
                            }
                        }
                    }
                    
                    // Also try in customers collection
                    database.child("customers").child(userId).observeSingleEvent(of: .value) { customerSnapshot in
                        if let userData = customerSnapshot.value as? [String: Any] {
                            if let fullName = userData["fullName"] as? String, !fullName.isEmpty {
                                DispatchQueue.main.async {
                                    self.customerNames[order.id] = fullName
                                }
                            }
                            
                            if let phone = userData["phone"] as? String, !phone.isEmpty {
                                DispatchQueue.main.async {
                                    self.customerPhones[order.id] = phone
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func loadNewOrders() {
        guard let restaurantId = authViewModel.currentUserId else {
            print("DEBUG: No restaurant ID available")
            return
        }
        
        print("DEBUG: Loading new orders for restaurant: '\(restaurantId)'")
        
        // Use a direct query to get all orders
        database.child("orders").observeSingleEvent(of: .value) { snapshot in
            print("DEBUG: Found \(snapshot.childrenCount) total orders in database")
            
            var newOrders: [Order] = []
            
            for child in snapshot.children {
                guard let snapshot = child as? DataSnapshot else { continue }
                guard let dict = snapshot.value as? [String: Any] else { continue }
                
                // Get status and restaurantId with detailed logging
                let status = (dict["status"] as? String ?? "").lowercased()
                let orderRestaurantId = dict["restaurantId"] as? String ?? ""
                
                print("DEBUG: Examining order \(snapshot.key)")
                print("DEBUG: Order status: '\(status)'")
                print("DEBUG: Order restaurantId: '\(orderRestaurantId)'")
                print("DEBUG: Current User ID: '\(restaurantId)'")
                print("DEBUG: Order matches user ID? \(orderRestaurantId == restaurantId)")
                
                // Check if this order has pending status
                if status == "pending" {
                    print("DEBUG: Found pending order: \(snapshot.key)")
                    
                    // Check if this order belongs to the current restaurant
                    if orderRestaurantId == restaurantId {
                        if let order = Order(id: snapshot.key, data: dict) {
                            print("DEBUG: Adding order to new orders list")
                            newOrders.append(order)
                        }
                    }
                }
            }
            
            print("DEBUG: Final count of pending orders: \(newOrders.count)")
            DispatchQueue.main.async {
                self.orders = newOrders.sorted { $0.createdAt > $1.createdAt }
                self.fetchCustomerNames()
            }
        }
    }
    
    private func acceptOrder(_ order: Order) {
        guard let restaurantId = authViewModel.currentUserId else {
            print("DEBUG: ❌ No restaurant ID available")
            return
        }

        // Update order status to in_progress and order_status to accepted
        let orderUpdates: [String: Any] = [
            "status": "in_progress",
            "order_status": "accepted",
            "restaurantId": restaurantId,  // Ensure correct restaurant ID
            "updatedAt": ServerValue.timestamp()
        ]
        
        database.child("orders").child(order.id).updateChildValues(orderUpdates) { error, _ in
            if let error = error {
                print("DEBUG: ❌ Error accepting order: \(error.localizedDescription)")
            } else {
                print("DEBUG: ✅ Successfully accepted order \(order.id)")
                print("DEBUG: 📊 Updated status to: in_progress, order_status to: accepted")
                
                // Manually verify the updates took effect
                self.database.child("orders").child(order.id).observeSingleEvent(of: .value) { snapshot in
                    if let dict = snapshot.value as? [String: Any] {
                        let status = dict["status"] as? String ?? ""
                        let orderStatus = dict["order_status"] as? String ?? ""
                        let updatedRestaurantId = dict["restaurantId"] as? String ?? ""
                        print("DEBUG: 🔍 Verification - Order \(order.id):")
                        print("DEBUG: 📊 status=\(status), order_status=\(orderStatus)")
                        print("DEBUG: 📊 restaurantId=\(updatedRestaurantId)")
                    }
                    
                // Notify that order status has changed
                DispatchQueue.main.async {
                        print("DEBUG: 📣 Posting OrderStatusChanged notification for order \(order.id)")
                    NotificationCenter.default.post(
                        name: Notification.Name("OrderStatusChanged"),
                        object: nil,
                            userInfo: [
                                "orderId": order.id,
                                "newStatus": "in_progress",
                                "newOrderStatus": "accepted"
                            ]
                        )
                    }
                }
            }
        }
    }
    
    private func rejectOrder(_ order: Order) {
        updateOrderStatus(order.id, status: "rejected")
    }
    
    private func updateOrderStatus(_ orderId: String, status: String) {
        database.child("orders").child(orderId).updateChildValues([
            "status": status,
            "updatedAt": ServerValue.timestamp()
        ])
    }
}

struct OrderCard: View {
    let order: Order
    let customerName: String
    let customerPhone: String?
    let onAccept: () -> Void
    let onReject: () -> Void
    @State private var isExpanded = false
    @State private var showDriverSelection = false
    @State private var driverName: String?
    @State private var driverPhone: String?
    @State private var driverLoadFailed: Bool = false
    @State private var driverLoaded: Bool = false
    
    init(order: Order, customerName: String, customerPhone: String? = nil, onAccept: @escaping () -> Void, onReject: @escaping () -> Void) {
        self.order = order
        self.customerName = customerName
        self.customerPhone = customerPhone
        self.onAccept = onAccept
        self.onReject = onReject
        
        // Initialize driver loading if there's a driver ID
        if let driverId = order.driverId {
            _driverLoaded = State(initialValue: false)
            _driverLoadFailed = State(initialValue: false)
            loadDriverInfo(driverId: driverId)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image("deligo_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .cornerRadius(15)
                
                VStack(alignment: .leading) {
                    Text("Order #\(order.id.prefix(8))")
                        .font(.headline)
                    Text("Customer: \(customerName)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Show status with displayed order status or general status if no specific one
                let displayStatus = order.orderStatus ?? order.status
                Text(displayStatus.capitalized)
                    .font(.caption)
                    .foregroundColor(statusColor(for: displayStatus))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(for: displayStatus).opacity(0.2))
                    .cornerRadius(4)
            }
            
            // Customer Details Section
            VStack(alignment: .leading, spacing: 8) {
                Text(order.deliveryOption.lowercased() == "pickup" ? "Pickup Details" : "Delivery Details")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if order.deliveryOption.lowercased() == "pickup" {
                    Text("Customer will pickup the order")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                } else {
                    Text("\(order.address.streetAddress), \(order.address.city), \(order.address.state) \(order.address.zipCode)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Text("Phone: \(customerPhone ?? order.customerPhone)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                if let instructions = order.specialInstructions, !instructions.isEmpty {
                    Text("Special Instructions:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(instructions)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)
            
            // Driver details section - only show if a driver is assigned
            if let driverId = order.driverId {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Driver Information")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if driverLoadFailed {
                        Text("Failed to load driver information")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    } else if let name = driverName {
                        Text("Name: \(name)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            
                        if let phone = driverPhone {
                            Text("Phone: \(phone)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text("Loading driver info...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .onAppear {
                                loadDriverInfo(driverId: driverId)
                            }
                    }
                }
                .padding(.vertical, 8)
            }
            
            Divider()
            
            // Updated Order Items display
            ForEach(order.items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(item.quantity)x")
                            .foregroundColor(.gray)
                        Text(item.name)
                        Spacer()
                        Text("$\(String(format: "%.2f", item.totalPrice))")
                            .foregroundColor(Color(hex: "F4A261"))
                    }
                    
                    ForEach(item.formattedOptions, id: \.id) { option in
                        Text("• \(option.displayText)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.leading)
                    }
                    
                    if let itemInstructions = item.specialInstructions, !itemInstructions.isEmpty {
                        Text("Note: \(itemInstructions)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.leading)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Divider()
            
            // Price Breakdown
            VStack(spacing: 8) {
                HStack {
                    Text("Subtotal")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("$\(String(format: "%.2f", order.subtotal))")
                }
                
                HStack {
                    Text("Delivery Fee")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("$\(String(format: "%.2f", order.deliveryFee))")
                }
                
                HStack {
                    Text("Total")
                        .fontWeight(.bold)
                    Spacer()
                    Text("$\(String(format: "%.2f", order.total))")
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "F4A261"))
                }
            }
            
            // Action Buttons - Update based on both status fields
            HStack(spacing: 12) {
                if order.status == "pending" {
                    Button(action: onReject) {
                        Text("REJECT")
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Button(action: onAccept) {
                        Text("ACCEPT")
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: "F4A261"))
                            .cornerRadius(8)
                    }
                } else if order.status == "in_progress" || order.status == "preparing" || order.status == "assigned_driver" {
                    if order.driverId == nil {
                        Button(action: {
                            showDriverSelection = true
                        }) {
                            Text("ASSIGN DRIVER")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(hex: "2196F3"))
                                .cornerRadius(8)
                        }
                        .sheet(isPresented: $showDriverSelection) {
                            DriverSelectionView(orderId: order.id)
                        }
                    } else {
                        // Check if order is already picked up
                        if order.status == "picked_up" {
                            Button(action: markAsDelivered) {
                                Text("MARK AS DELIVERED")
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: "F4A261"))
                                    .cornerRadius(8)
                            }
                        } else {
                            Button(action: markAsPickedUp) {
                                Text("MARK AS PICKED UP")
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: "4CAF50"))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "pending":
            return .orange
        case "preparing", "in_progress":
            return .blue
        case "delivered":
            return .green
        case "rejected":
            return .red
        case "assigned_driver":
            return .purple
        case "picked_up":
            return Color(hex: "4CAF50") // Green for picked up
        default:
            return .gray
        }
    }
    
    private func loadDriverInfo(driverId: String) {
        print("DEBUG: Loading driver info for driverId: \(driverId)")
        let database = Database.database().reference()
        
        database.child("drivers").child(driverId).observeSingleEvent(of: .value) { snapshot in
            if !snapshot.exists() {
                print("DEBUG: No driver found with ID: \(driverId)")
                DispatchQueue.main.async {
                    self.driverLoadFailed = true
                }
                return
            }
            
            guard let dict = snapshot.value as? [String: Any] else {
                print("DEBUG: Driver data could not be parsed for ID: \(driverId)")
                DispatchQueue.main.async {
                    self.driverLoadFailed = true
                }
                return
            }
            
            // Try to get user info from different possible locations
            var foundName: String?
            var foundPhone: String?
            
            // Try user_info structure first
            if let userInfo = dict["user_info"] as? [String: Any] {
                foundName = userInfo["fullName"] as? String
                foundPhone = userInfo["phone"] as? String
            }
            
            // If not found in user_info, try top level
            if foundName == nil {
                foundName = dict["fullName"] as? String
            }
            if foundPhone == nil {
                foundPhone = dict["phone"] as? String
            }
            
            // If still no name, try other variations
            if foundName == nil {
                if let firstName = dict["firstName"] as? String,
                   let lastName = dict["lastName"] as? String {
                    foundName = "\(firstName) \(lastName)"
                } else if let email = dict["email"] as? String {
                    foundName = email
                }
            }
            
            DispatchQueue.main.async {
                if let name = foundName {
                    self.driverName = name
                    self.driverPhone = foundPhone
                    self.driverLoaded = true
                    print("DEBUG: Successfully loaded driver name: \(name)")
                } else {
                    self.driverLoadFailed = true
                    print("DEBUG: Could not find driver name in any expected location")
                }
            }
        }
    }
    
    private func markAsDelivered() {
        let database = Database.database().reference()
        
        database.child("orders").child(order.id).updateChildValues([
            "status": "delivered",
            "order_status": "delivered",
            "updatedAt": ServerValue.timestamp()
        ]) { error, _ in
            if let error = error {
                print("DEBUG: Error marking order as delivered: \(error.localizedDescription)")
            } else {
                print("DEBUG: Order \(order.id) marked as delivered successfully")
                // Use NotificationCenter to signal that orders need to be refreshed
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name("OrderStatusChanged"),
                        object: nil,
                        userInfo: ["orderId": order.id]
                    )
                }
            }
        }
    }
    
    // Add a new function in the OrderCard struct to mark an order as picked up
    private func markAsPickedUp() {
        let database = Database.database().reference()
        
        database.child("orders").child(order.id).updateChildValues([
            "status": "picked_up",
            "order_status": "picked_up",
            "updatedAt": ServerValue.timestamp()
        ]) { error, _ in
            if let error = error {
                print("DEBUG: Error marking order as picked up: \(error.localizedDescription)")
            } else {
                print("DEBUG: Order \(order.id) marked as picked up successfully")
                // Use NotificationCenter to signal that orders need to be refreshed
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name("OrderStatusChanged"),
                        object: nil,
                        userInfo: ["orderId": order.id]
                    )
                }
            }
        }
    }
}

// Add a new DriverSelectionView to handle driver assignments
struct DriverSelectionView: View {
    let orderId: String
    @State private var drivers: [Driver] = []
    @State private var busyDrivers: [Driver] = [] // New state for busy drivers
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedDriverId: String?
    @State private var showAllDrivers = true // Default to showing all drivers
    @State private var showForceAssignAlert = false
    @State private var showResetDriverAlert = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading available drivers...")
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                    
                    Button("Try Again") {
                        loadDrivers()
                    }
                    .padding()
                } else if drivers.isEmpty && busyDrivers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                            .padding(.bottom, 8)
                        
                        Text("No Drivers Found")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("There are no drivers in the system")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        Button("Refresh") {
                            loadDrivers()
                        }
                        .padding()
                        .background(Color(hex: "F4A261"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                } else {
                    // Driver display section
                    VStack {
                        // Show driver type toggle
                        if !busyDrivers.isEmpty || !drivers.isEmpty {
                            Toggle("Show All Drivers", isOn: $showAllDrivers)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }
                        
                        // The main list of drivers
                        List {
                            if showAllDrivers {
                                // Show all drivers section
                                if !drivers.isEmpty {
                                    Section(header: Text("Available Drivers")) {
                                        ForEach(drivers) { driver in
                                            DriverRow(
                                                driver: driver,
                                                isSelected: selectedDriverId == driver.id,
                                                isBusy: !driver.isAvailable
                                            ) {
                                                selectedDriverId = driver.id
                                            }
                                        }
                                    }
                                }
                                
                                if !busyDrivers.isEmpty {
                                    Section(header: Text("Busy Drivers")) {
                                        ForEach(busyDrivers) { driver in
                                            DriverRow(
                                                driver: driver,
                                                isSelected: selectedDriverId == driver.id,
                                                isBusy: true
                                            ) {
                                                selectedDriverId = driver.id
                                                // Show warning if selecting a busy driver
                                                if let _ = driver.currentOrderId {
                                                    showForceAssignAlert = true
                                                }
                                            }
                                            .contextMenu {
                                                Button(action: {
                                                    selectedDriverId = driver.id
                                                    showResetDriverAlert = true
                                                }) {
                                                    Label("Make Available", systemImage: "arrow.triangle.2.circlepath")
                                                }
                                            }
                                        }
                                    }
                                }
                            } else {
                                // Only show available drivers
                                ForEach(drivers) { driver in
                                    DriverRow(
                                        driver: driver,
                                        isSelected: selectedDriverId == driver.id,
                                        isBusy: !driver.isAvailable
                                    ) {
                                        selectedDriverId = driver.id
                                    }
                                }
                            }
                        }
                    }
                    
                    // Action buttons
                    VStack(spacing: 10) {
                        Button("Assign Selected Driver") {
                            // Check if selected driver is busy
                            let selectedDriver = (drivers + busyDrivers).first(where: { $0.id == selectedDriverId })
                            if let driver = selectedDriver, let _ = driver.currentOrderId {
                                showForceAssignAlert = true
                            } else {
                                assignDriver()
                            }
                        }
                        .disabled(selectedDriverId == nil)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(selectedDriverId == nil ? Color.gray : Color(hex: "F4A261"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    .padding(.bottom)
                }
            }
            .navigationTitle("Select Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadDrivers()
            }
            .alert(isPresented: $showForceAssignAlert) {
                Alert(
                    title: Text("Driver Is Busy"),
                    message: Text("This driver is currently assigned to another order. Assigning them to this order will remove them from their current assignment."),
                    primaryButton: .destructive(Text("Force Assign")) {
                        assignDriver(forceAssign: true)
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert(isPresented: $showResetDriverAlert) {
                Alert(
                    title: Text("Reset Driver Status"),
                    message: Text("This will clear the driver's current order and set them as available. Continue?"),
                    primaryButton: .destructive(Text("Reset Status")) {
                        resetDriverStatus()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private func loadDrivers() {
        isLoading = true
        errorMessage = nil
        drivers = []
        busyDrivers = []
        
        let database = Database.database().reference()
        print("DEBUG: Loading all drivers...")
        
        // Load all drivers
        database.child("drivers").observeSingleEvent(of: .value) { snapshot in
            print("DEBUG: Total drivers in database: \(snapshot.childrenCount)")
            
            if snapshot.childrenCount == 0 {
                isLoading = false
                errorMessage = "No drivers found in the system"
                return
            }
            
            var availableDrivers: [Driver] = []
            var unavailableDrivers: [Driver] = []
            
            for child in snapshot.children {
                guard let driverSnapshot = child as? DataSnapshot else { continue }
                let driverId = driverSnapshot.key
                print("DEBUG: Found driver with ID: \(driverId)")
                
                guard let dict = driverSnapshot.value as? [String: Any] else { 
                    print("DEBUG: Could not parse driver data for \(driverId)")
                    continue 
                }
                
                // Check if driver is available
                let isAvailable = dict["isAvailable"] as? Bool ?? false
                let currentOrderId = dict["currentOrderId"] as? String
                let isBusy = currentOrderId != nil && !currentOrderId!.isEmpty
                
                print("DEBUG: Driver \(driverId) - Available: \(isAvailable), Has order: \(isBusy)")
                
                // Try to be flexible with document status checking
                var isApproved = true
                if let documents = dict["documents"] as? [String: Any],
                   let status = documents["status"] as? String {
                    isApproved = status == "approved"
                    if !isApproved {
                        print("DEBUG: Driver \(driverId) has non-approved document status: \(status)")
                    }
                } else if let documentsSubmitted = dict["documentsSubmitted"] as? Bool {
                    // Fall back to documentsSubmitted if no status is available
                    isApproved = documentsSubmitted
                    if !isApproved {
                        print("DEBUG: Driver \(driverId) has documentsSubmitted=false")
                    }
                }
                
                if !isApproved {
                    continue
                }
                
                // Get driver name and phone - be flexible with the structure
                var driverName: String?
                var driverPhone: String?
                
                // Try user_info structure first
                if let userInfo = dict["user_info"] as? [String: Any] {
                    driverName = userInfo["fullName"] as? String
                    driverPhone = userInfo["phone"] as? String
                }
                
                // If not found, try top level
                if driverName == nil {
                    driverName = dict["fullName"] as? String
                }
                if driverPhone == nil {
                    driverPhone = dict["phone"] as? String
                }
                
                // If we still don't have a name, try different variations
                if driverName == nil {
                    if let firstName = dict["firstName"] as? String,
                       let lastName = dict["lastName"] as? String {
                        driverName = "\(firstName) \(lastName)"
                    } else if let email = dict["email"] as? String {
                        // Use email as a fallback name
                        driverName = email
                    } else if let role = dict["role"] as? String {
                        // Use role as a last resort
                        driverName = "Driver (\(role))"
                    }
                }
                
                guard let finalName = driverName else {
                    print("DEBUG: Could not determine name for driver \(driverId)")
                    continue
                }
                
                let finalPhone = driverPhone ?? "No Phone"
                let rating = dict["rating"] as? Double ?? 0.0
                let totalRides = dict["totalRides"] as? Int ?? 0
                
                // Create the driver object - note we're setting isAvailable based on Firebase value,
                // not our computed value
                let driver = Driver(
                    id: driverId,
                    name: finalName,
                    phone: finalPhone,
                    rating: rating,
                    totalRides: totalRides,
                    isAvailable: isAvailable && !isBusy, 
                    currentOrderId: currentOrderId
                )
                
                // Add to appropriate list
                if isAvailable && !isBusy {
                    print("DEBUG: Adding driver: \(finalName) to available drivers list")
                    availableDrivers.append(driver)
                } else {
                    print("DEBUG: Adding driver: \(finalName) to busy drivers list")
                    unavailableDrivers.append(driver)
                }
            }
            
            DispatchQueue.main.async {
                isLoading = false
                drivers = availableDrivers.sorted { $0.rating > $1.rating }
                busyDrivers = unavailableDrivers.sorted { $0.rating > $1.rating }
                
                if availableDrivers.isEmpty {
                    print("DEBUG: No available drivers after filtering. Found \(unavailableDrivers.count) busy drivers.")
                } else {
                    print("DEBUG: Final available drivers count: \(availableDrivers.count)")
                }
            }
        }
    }
    
    private func assignDriver(forceAssign: Bool = false) {
        guard let driverId = selectedDriverId else { return }
        
        isLoading = true
        let database = Database.database().reference()
        print("DEBUG: Assigning driver \(driverId) to order \(orderId)")
        
        // First verify that the driver exists
        database.child("drivers").child(driverId).observeSingleEvent(of: .value) { snapshot in
            if !snapshot.exists() {
                isLoading = false
                errorMessage = "Selected driver no longer exists"
                print("DEBUG: Driver \(driverId) no longer exists")
                return
            }
            
            guard let dict = snapshot.value as? [String: Any] else {
                isLoading = false
                errorMessage = "Could not read driver data"
                print("DEBUG: Could not parse driver data for \(driverId)")
                return
            }
            
            // Get the current order ID
            let currentOrderId = dict["currentOrderId"] as? String
            
            // If the driver is busy and we're not force assigning, show alert
            if !forceAssign && currentOrderId != nil && !currentOrderId!.isEmpty {
                isLoading = false
                showForceAssignAlert = true
                return
            }
            
            // If driver has a current order and we're force assigning, clear that assignment first
            if forceAssign && currentOrderId != nil && !currentOrderId!.isEmpty {
                print("DEBUG: Force assigning driver. Clearing previous order \(currentOrderId!)")
                
                // Clear the driver ID from the previous order
                database.child("orders").child(currentOrderId!).updateChildValues([
                    "driverId": NSNull(),
                    "driverName": NSNull()
                ]) { error, _ in
                    if let error = error {
                        print("DEBUG: Error clearing previous order: \(error.localizedDescription)")
                    } else {
                        print("DEBUG: Successfully cleared driver from previous order")
                    }
                    
                    // Continue with assignment regardless
                    self.completeDriverAssignment(driverId: driverId, driverData: dict)
                }
            } else {
                // No previous order to clear, proceed with assignment
                self.completeDriverAssignment(driverId: driverId, driverData: dict)
            }
        }
    }
    
    private func completeDriverAssignment(driverId: String, driverData: [String: Any]) {
        let database = Database.database().reference()
        
        // Get the driver's name for the order update
        var driverName: String?
        
        // Try different locations for the driver name
        if let userInfo = driverData["user_info"] as? [String: Any] {
            driverName = userInfo["fullName"] as? String
        }
        if driverName == nil {
            driverName = driverData["fullName"] as? String
        }
        if driverName == nil {
            driverName = driverData["email"] as? String
        }
        
        let finalDriverName = driverName ?? "Assigned Driver"
        print("DEBUG: Using driver name: \(finalDriverName) for assignment")
        
        // Driver exists and is available, proceed with assignment
        let orderUpdates: [String: Any] = [
            "driverId": driverId,
            "status": "assigned_driver",
            "order_status": "preparing",
            "driverName": finalDriverName,
            "updatedAt": ServerValue.timestamp()
        ]
        
        // Update the driver data
        let driverUpdates: [String: Any] = [
            "isAvailable": false,
            "currentOrderId": self.orderId
        ]
        
        print("DEBUG: Updating order data with driver assignment")
        database.child("orders").child(orderId).updateChildValues(orderUpdates) { error, _ in
            if let error = error {
                isLoading = false
                errorMessage = "Failed to assign driver to order: \(error.localizedDescription)"
                print("DEBUG: Error updating order: \(error.localizedDescription)")
                return
            }
            
            print("DEBUG: Successfully updated order with driver. Now updating driver data.")
            
            // Now update the driver data
            database.child("drivers").child(driverId).updateChildValues(driverUpdates) { error, _ in
                isLoading = false
                
                if let error = error {
                    errorMessage = "Driver assigned but driver data update failed: \(error.localizedDescription)"
                    print("DEBUG: Error updating driver data: \(error.localizedDescription)")
                } else {
                    print("DEBUG: Successfully updated driver data")
                    
                    // Notify the driver about the new order
                    let notification = [
                        "orderId": orderId,
                        "type": "new_order",
                        "timestamp": ServerValue.timestamp(),
                        "read": false
                    ] as [String: Any]
                    
                    database.child("driver_notifications").child(driverId).childByAutoId().setValue(notification)
                    
                    // Notify UI to update
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: Notification.Name("OrderStatusChanged"),
                            object: nil,
                            userInfo: ["orderId": orderId]
                        )
                    }
                }
                
                // Close the sheet regardless of final driver data update
                dismiss()
            }
        }
    }
    
    private func resetDriverStatus() {
        guard let driverId = selectedDriverId else { return }
        
        isLoading = true
        let database = Database.database().reference()
        print("DEBUG: Resetting driver status for \(driverId)")
        
        // Get the driver data to know which order to clear
        database.child("drivers").child(driverId).observeSingleEvent(of: .value) { snapshot in
            guard let dict = snapshot.value as? [String: Any] else {
                isLoading = false
                errorMessage = "Could not read driver data"
                return
            }
            
            // Get the current order ID if any
            if let currentOrderId = dict["currentOrderId"] as? String, !currentOrderId.isEmpty {
                // Clear the driver ID from the order
                database.child("orders").child(currentOrderId).updateChildValues([
                    "driverId": NSNull(),
                    "driverName": NSNull()
                ]) { error, _ in
                    if let error = error {
                        print("DEBUG: Error clearing driver from order: \(error.localizedDescription)")
                    } else {
                        print("DEBUG: Successfully cleared driver from order \(currentOrderId)")
                    }
                }
            }
            
            // Update the driver to be available with no current order
            database.child("drivers").child(driverId).updateChildValues([
                "isAvailable": true,
                "currentOrderId": NSNull()
            ]) { error, _ in
                isLoading = false
                
                if let error = error {
                    errorMessage = "Failed to reset driver status: \(error.localizedDescription)"
                    print("DEBUG: Error resetting driver status: \(error.localizedDescription)")
                } else {
                    print("DEBUG: Successfully reset driver status")
                    // Reload the drivers list
                    loadDrivers()
                }
            }
        }
    }
}

// Update DriverRow to show more context when a driver is busy
struct DriverRow: View {
    let driver: Driver
    let isSelected: Bool
    let isBusy: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(driver.name)
                        .font(.headline)
                        .foregroundColor(isBusy ? .gray : .primary)
                    
                    if isBusy {
                        Text("(Busy)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Text("Rating: \(String(format: "%.1f", driver.rating)) ⭐️")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("Total Rides: \(driver.totalRides)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if let orderId = driver.currentOrderId {
                    Text("Current Order: #\(orderId.prefix(8))")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "F4A261"))
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .opacity(isBusy ? 0.7 : 1.0)
        .onTapGesture {
            onSelect()
        }
    }
}

struct Driver: Identifiable {
    let id: String
    let name: String
    let phone: String
    let rating: Double
    let totalRides: Int
    let isAvailable: Bool
    let currentOrderId: String?
}

struct Order: Identifiable {
    let id: String
    let customerName: String
    let customerId: String
    let userId: String
    let customerPhone: String
    let address: DeliveryAddress
    let items: [OrderItem]
    let total: Double
    let subtotal: Double
    let deliveryFee: Double
    let status: String
    let orderStatus: String?
    let createdAt: TimeInterval
    let updatedAt: TimeInterval?
    let restaurantId: String
    let specialInstructions: String?
    let deliveryOption: String
    let driverId: String?
    
    init?(id: String, data: [String: Any]) {
        self.id = id
        
        // Extract customer ID and user ID
        self.customerId = data["customerId"] as? String ?? ""
        self.userId = data["userId"] as? String ?? ""
        
        print("DEBUG: Order \(id) has customerId: \(self.customerId), userId: \(self.userId)")
        
        // Initially set customer name from order data
        self.customerName = data["customerName"] as? String ?? "Unknown Customer"
        self.customerPhone = data["customerPhone"] as? String ?? "No Phone"
        
        // Extract price information with fallbacks
        self.total = data["total"] as? Double ?? 0.0
        self.subtotal = data["subtotal"] as? Double ?? 0.0
        self.deliveryFee = data["deliveryFee"] as? Double ?? 0.0
        
        // Handle both status and order_status fields
        let rawStatus = (data["status"] as? String ?? "pending").lowercased()
        let rawOrderStatus = (data["order_status"] as? String ?? "").lowercased()
        
        // Use order_status if available, otherwise use status
        self.status = rawStatus
        self.orderStatus = rawOrderStatus.isEmpty ? nil : rawOrderStatus
        
        print("DEBUG: Order \(id) - Raw status: '\(rawStatus)', Raw order_status: '\(rawOrderStatus)'")
        print("DEBUG: Order \(id) - Final status: '\(self.status)', Final order_status: '\(String(describing: self.orderStatus))'")
        
        // Extract timestamps
        self.createdAt = data["createdAt"] as? TimeInterval ?? 0
        self.updatedAt = data["updatedAt"] as? TimeInterval
        
        // Extract and verify restaurant ID
        let rawRestaurantId = data["restaurantId"] as? String ?? ""
        print("DEBUG: Order \(id) restaurantId: \(rawRestaurantId)")
        self.restaurantId = rawRestaurantId
        
        // Store driver ID if assigned
        self.driverId = data["driverId"] as? String
        
        self.specialInstructions = data["specialInstructions"] as? String
        self.deliveryOption = data["deliveryOption"] as? String ?? "Delivery"
        
        // Parse address
        if let addressData = data["address"] as? [String: Any] {
            print("DEBUG: Order \(id) has address data")
            self.address = DeliveryAddress(
                streetAddress: addressData["street"] as? String ?? "",
                city: addressData["city"] as? String ?? "",
                state: addressData["state"] as? String ?? "",
                zipCode: addressData["zipCode"] as? String ?? "",
                unit: addressData["unit"] as? String ?? "",
                instructions: addressData["instructions"] as? String ?? "",
                latitude: addressData["latitude"] as? Double ?? 0.0,
                longitude: addressData["longitude"] as? Double ?? 0.0,
                placeID: addressData["placeID"] as? String ?? ""
            )
        } else {
            print("DEBUG: Order \(id) has NO address data")
            self.address = DeliveryAddress(
                streetAddress: "No Address",
                city: "",
                state: "",
                zipCode: "",
                unit: "",
                instructions: "",
                latitude: 0.0,
                longitude: 0.0,
                placeID: ""
            )
        }
        
        // Parse items
        if let itemsData = data["items"] as? [[String: Any]] {
            print("DEBUG: Order \(id) has \(itemsData.count) items")
            self.items = itemsData.compactMap { OrderItem(data: $0) }
        } else {
            print("DEBUG: Order \(id) has NO items")
            self.items = []
        }
        
        // Fetch customer information from different sources
        if !self.customerId.isEmpty {
            fetchCustomerName(customerId: self.customerId)
        }
        
        if !self.userId.isEmpty && self.userId != self.customerId {
            fetchUserInfo(userId: self.userId)
        }
    }
    
    // Function to fetch customer's information from Firebase
    private func fetchCustomerName(customerId: String) {
        let database = Database.database().reference()
        print("DEBUG: Fetching customer data for ID: \(customerId)")
        
        database.child("customers").child(customerId).observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                if let userData = snapshot.value as? [String: Any] {
                    // Try to get fullName directly
                    var fullName = userData["fullName"] as? String ?? ""
                    
                    // If no fullName, check for both first and last name
                    if fullName.isEmpty {
                        let firstName = userData["firstName"] as? String ?? ""
                        let lastName = userData["lastName"] as? String ?? ""
                        
                        if !firstName.isEmpty || !lastName.isEmpty {
                            fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    
                    // Get phone number
                    var phoneNumber = userData["phone"] as? String ?? ""
                    
                    // If we found either name or phone, update them
                    if !fullName.isEmpty || !phoneNumber.isEmpty {
                        print("DEBUG: Found customer data - Name: \(fullName), Phone: \(phoneNumber)")
                        self.updateCustomerInfo(name: fullName, phone: phoneNumber)
                    }
                }
                
                // If we couldn't find the info in the customer's node, let's try direct field lookups
                if !snapshot.hasChild("fullName") && !snapshot.hasChild("phone") {
                    let nameRef = database.child("customers").child(customerId).child("fullName")
                    let phoneRef = database.child("customers").child(customerId).child("phone")
                    
                    nameRef.observeSingleEvent(of: .value) { nameSnapshot in
                        phoneRef.observeSingleEvent(of: .value) { phoneSnapshot in
                            let name = nameSnapshot.value as? String ?? ""
                            let phone = phoneSnapshot.value as? String ?? ""
                            
                            if !name.isEmpty || !phone.isEmpty {
                                print("DEBUG: Found customer data directly - Name: \(name), Phone: \(phone)")
                                self.updateCustomerInfo(name: name, phone: phone)
                            }
                        }
                    }
                }
            } else {
                print("DEBUG: Customer with ID: \(customerId) does not exist")
            }
        }
    }
    
    // Add function to fetch user info directly from users collection
    private func fetchUserInfo(userId: String) {
        let database = Database.database().reference()
        print("DEBUG: Fetching user data for userId: \(userId)")
        
        // Check in users collection
        database.child("users").child(userId).observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                if let userData = snapshot.value as? [String: Any] {
                    print("DEBUG: Found user data in users collection")
                    
                    // Extract user info
                    var fullName = userData["fullName"] as? String ?? ""
                    let firstName = userData["firstName"] as? String ?? ""
                    let lastName = userData["lastName"] as? String ?? ""
                    let phone = userData["phone"] as? String ?? ""
                    
                    // Construct name if needed
                    if fullName.isEmpty && (!firstName.isEmpty || !lastName.isEmpty) {
                        fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    // Update if we found anything
                    if !fullName.isEmpty || !phone.isEmpty {
                        print("DEBUG: Updating from users: name=\(fullName), phone=\(phone)")
                        self.updateCustomerInfo(name: fullName, phone: phone)
                    }
                }
            } else {
                print("DEBUG: No user found in users collection for ID: \(userId)")
            }
        }
    }
    
    private func updateCustomerInfo(name: String, phone: String) {
        var userInfo: [String: Any] = ["orderId": self.id]
        
        if !name.isEmpty {
            userInfo["customerName"] = name
        }
        
        if !phone.isEmpty {
            userInfo["customerPhone"] = phone
        }
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("CustomerInfoUpdated"),
                object: nil,
                userInfo: userInfo
            )
        }
    }
}

struct OrderItem: Identifiable {
    let id: String
    let name: String
    let quantity: Int
    let price: Double
    let totalPrice: Double
    let specialInstructions: String?
    let options: [String: Any]?
    let menuItemId: String
    let description: String
    let imageURL: String?
    
    // Rename to avoid conflicts
    var formattedOptions: [OrderItemOptionDisplay] {
        var result: [OrderItemOptionDisplay] = []
        
        // Parse customizations properly
        if let options = self.options {
            for (optionId, optionData) in options {
                if let optionDict = optionData as? [String: Any] {
                    // Extract option name and selected items
                    let optionName = optionDict["optionName"] as? String ?? "Option"
                    
                    if let selectedItems = optionDict["selectedItems"] as? [[String: Any]] {
                        var selections: [String] = []
                        
                        for item in selectedItems {
                            if let name = item["name"] as? String {
                                selections.append(name)
                            }
                        }
                        
                        if !selections.isEmpty {
                            result.append(OrderItemOptionDisplay(name: optionName, selections: selections))
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    init?(data: [String: Any]) {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String,
              let quantity = data["quantity"] as? Int,
              let price = data["price"] as? Double else { return nil }
        
        self.id = id
        self.name = name
        self.quantity = quantity
        self.price = price
        self.totalPrice = price * Double(quantity)
        self.specialInstructions = data["specialInstructions"] as? String
        self.options = data["customizations"] as? [String: Any]
        self.menuItemId = data["menuItemId"] as? String ?? ""
        self.description = data["description"] as? String ?? ""
        self.imageURL = data["imageURL"] as? String
    }
}

// Replace the DisplayOptionItem struct with a completely different name
struct OrderItemOptionDisplay: Identifiable {
    let id = UUID()
    let name: String
    let selections: [String]
    
    var displayText: String {
        return "\(name): \(selections.joined(separator: ", "))"
    }
}

struct InProgressOrdersView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var orders: [Order] = []
    @State private var customerNames: [String: String] = [:]
    @State private var customerPhones: [String: String] = [:]
    @State private var isLoading = false
    private let database = Database.database().reference()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if isLoading {
                    ProgressView("Loading orders...")
                        .padding(.top, 50)
                } else if orders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Orders In Progress")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Orders being prepared will appear here")
                            .foregroundColor(.gray)
                            
                        Button(action: {
                            isLoading = true
                            loadInProgressOrders()
                            // Add a minimum delay to make the loading state visible
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isLoading = false
                            }
                        }) {
                            Text("Refresh Orders")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(Color(hex: "F4A261"))
                                .cornerRadius(8)
                        }
                        .padding(.top, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else {
                    ForEach(orders) { order in
                        OrderCard(
                            order: order,
                            customerName: customerNames[order.id] ?? order.customerName,
                            customerPhone: customerPhones[order.id],
                            onAccept: {
                                markAsDelivered(order)
                            },
                            onReject: {
                                // No reject option for in-progress orders
                            }
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            isLoading = true
            loadInProgressOrders()
            // Add a minimum delay to make the loading state visible
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isLoading = false
            }
        }
        .onAppear {
            isLoading = true
            loadInProgressOrders()
            
            // Listen for customer info updates
            NotificationCenter.default.addObserver(
                forName: Notification.Name("CustomerInfoUpdated"),
                object: nil,
                queue: .main
            ) { notification in
                if let userInfo = notification.userInfo,
                   let orderId = userInfo["orderId"] as? String {
                    if let name = userInfo["customerName"] as? String {
                        customerNames[orderId] = name
                    }
                    if let phone = userInfo["customerPhone"] as? String {
                        customerPhones[orderId] = phone
                    }
                }
            }
            
            // Listen for order status changes
            NotificationCenter.default.addObserver(
                forName: Notification.Name("OrderStatusChanged"),
                object: nil,
                queue: .main
            ) { notification in
                print("DEBUG: 🔔 Received order status change notification in InProgressOrdersView")
                if let userInfo = notification.userInfo,
                   let orderId = userInfo["orderId"] as? String {
                    print("DEBUG: 🔔 Order status changed for order ID: \(orderId)")
                }
                
                // Always refresh orders when we get a notification
                DispatchQueue.main.async {
                    isLoading = true
                    print("DEBUG: 🔄 Refreshing in-progress orders after status change")
                    self.loadInProgressOrders()
                    // Add a minimum delay to make the loading state visible
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isLoading = false
                    }
                }
            }
            
            // Add a minimum delay to make the loading state visible
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isLoading = false
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    private func fetchCustomerNames() {
        print("DEBUG: Fetching customer info for \(orders.count) in-progress orders")
        let database = Database.database().reference()
        
        for order in orders {
            // Try with customerId first
            if !order.customerId.isEmpty {
                // Fetch both name and phone
                database.child("customers").child(order.customerId).observeSingleEvent(of: .value) { snapshot in
                    if let userData = snapshot.value as? [String: Any] {
                        // Handle name
                        if let fullName = userData["fullName"] as? String, !fullName.isEmpty {
                            DispatchQueue.main.async {
                                self.customerNames[order.id] = fullName
                            }
                        }
                        
                        // Handle phone
                        if let phone = userData["phone"] as? String, !phone.isEmpty {
                            DispatchQueue.main.async {
                                self.customerPhones[order.id] = phone
                            }
                        }
                    }
                }
            }
            
            // Also check users collection with userId if available
            database.child("orders").child(order.id).child("userId").observeSingleEvent(of: .value) { snapshot in
                if let userId = snapshot.value as? String, !userId.isEmpty {
                    // Try in users collection
                    database.child("users").child(userId).observeSingleEvent(of: .value) { userSnapshot in
                        if let userData = userSnapshot.value as? [String: Any] {
                            if let fullName = userData["fullName"] as? String, !fullName.isEmpty {
                                DispatchQueue.main.async {
                                    self.customerNames[order.id] = fullName
                                }
                            }
                            
                            if let phone = userData["phone"] as? String, !phone.isEmpty {
                                DispatchQueue.main.async {
                                    self.customerPhones[order.id] = phone
                                }
                            }
                        }
                    }
                }
            }
            
            // Also try in customers collection
            database.child("customers").child(order.userId).observeSingleEvent(of: .value) { customerSnapshot in
                if let userData = customerSnapshot.value as? [String: Any] {
                    if let fullName = userData["fullName"] as? String, !fullName.isEmpty {
                        DispatchQueue.main.async {
                            self.customerNames[order.id] = fullName
                        }
                    }
                    
                    if let phone = userData["phone"] as? String, !phone.isEmpty {
                        DispatchQueue.main.async {
                            self.customerPhones[order.id] = phone
                        }
                    }
                }
            }
        }
    }
    
    private func loadInProgressOrders() {
        guard let restaurantId = authViewModel.currentUserId else { 
            print("DEBUG: No restaurant ID available")
            return 
        }
        
        print("DEBUG: 🔍 Loading in-progress orders for restaurant: \(restaurantId)")
        
        // Use a single observation to prevent multiple listeners
        database.child("orders").observeSingleEvent(of: .value) { snapshot in
            print("DEBUG: 🔍 Found \(snapshot.childrenCount) total orders in database")
            
            var inProgressOrders: [Order] = []
            
            for child in snapshot.children {
                guard let snapshot = child as? DataSnapshot else { continue }
                guard let dict = snapshot.value as? [String: Any] else { continue }
                
                let status = (dict["status"] as? String ?? "").lowercased()
                let orderStatus = (dict["order_status"] as? String ?? "").lowercased()
                let orderRestaurantId = dict["restaurantId"] as? String ?? ""
                
                print("DEBUG: 🔎 Examining order \(snapshot.key)")
                print("DEBUG: 📊 Status: '\(status)', OrderStatus: '\(orderStatus)', RestaurantId: '\(orderRestaurantId)'")
                
                // Only process orders for this restaurant
                if orderRestaurantId == restaurantId {
                    // Check various status combinations that should appear in In Progress tab
                    let shouldShow = (
                        (status == "in_progress" && orderStatus == "accepted") ||  // Accepted orders
                        status == "preparing" ||                                   // Preparing orders
                        status == "assigned_driver" ||                            // Orders assigned to drivers
                        status == "picked_up" ||                                  // Orders picked up by drivers
                        (status == "in_progress" && orderStatus == "ready_for_pickup") // Ready for pickup
                    )
                    
                    if shouldShow {
                        print("DEBUG: ✅ Adding order \(snapshot.key) to in-progress list")
                        print("DEBUG: 📊 Order status=\(status), orderStatus=\(orderStatus)")
                        
                        if let order = Order(id: snapshot.key, data: dict) {
                        inProgressOrders.append(order)
                            print("DEBUG: ✅ Successfully added order to in-progress list")
                    }
                    } else {
                        print("DEBUG: ❌ Order \(snapshot.key) does not meet in-progress criteria")
                    }
                } else {
                    print("DEBUG: ❌ Order \(snapshot.key) belongs to different restaurant")
                }
            }
            
            print("DEBUG: 📊 Final count of in-progress orders: \(inProgressOrders.count)")
            
            DispatchQueue.main.async {
                self.orders = inProgressOrders.sorted { $0.createdAt > $1.createdAt }
                print("DEBUG: 📱 UI updated with \(self.orders.count) in-progress orders")
                self.fetchCustomerNames()
            }
        }
    }
    
    private func markAsDelivered(_ order: Order) {
        database.child("orders").child(order.id).updateChildValues([
            "status": "delivered",
            "order_status": "delivered",
            "updatedAt": ServerValue.timestamp()
        ]) { error, _ in
            if let error = error {
                print("DEBUG: Error marking order as delivered: \(error.localizedDescription)")
            } else {
                print("DEBUG: Order \(order.id) marked as delivered successfully")
                // Use NotificationCenter to signal that orders need to be refreshed
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name("OrderStatusChanged"),
                        object: nil,
                        userInfo: ["orderId": order.id]
                    )
                }
            }
        }
    }
    
    // Add function to validate driver assignments
    private func validateDriverAssignment(orderId: String, driverId: String) {
        print("DEBUG: Validating driver assignment for order: \(orderId), driver: \(driverId)")
        let database = Database.database().reference()
        
        database.child("drivers").child(driverId).observeSingleEvent(of: .value) { snapshot in
            if !snapshot.exists() {
                print("DEBUG: ⚠️ Invalid driver assignment - driver \(driverId) does not exist")
                // Remove the invalid driver assignment
                database.child("orders").child(orderId).child("driverId").removeValue { error, _ in
                    if let error = error {
                        print("DEBUG: Error removing invalid driver assignment: \(error.localizedDescription)")
                    } else {
                        print("DEBUG: Successfully removed invalid driver assignment")
                        // Notify UI to update
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(
                                name: Notification.Name("OrderStatusChanged"),
                                object: nil,
                                userInfo: ["orderId": orderId]
                            )
                        }
                    }
                }
            }
        }
    }
}

struct DeliveredOrdersView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var orders: [Order] = []
    @State private var isLoading = false
    @State private var customerNames: [String: String] = [:] // To store updated customer names
    @State private var customerPhones: [String: String] = [:] // To store updated customer phones
    private let database = Database.database().reference()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if isLoading {
                    ProgressView("Loading orders...")
                        .padding(.top, 50)
                } else if orders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Delivered Orders")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Completed orders will appear here")
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            refreshOrders()
                        }) {
                            Text("Refresh Orders")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(Color(hex: "F4A261"))
                                .cornerRadius(8)
                        }
                        .padding(.top, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else {
                    ForEach(orders) { order in
                        OrderCard(
                            order: order,
                            customerName: customerNames[order.id] ?? order.customerName,
                            customerPhone: customerPhones[order.id] ?? order.customerPhone,
                            onAccept: {
                                // No action needed for delivered orders
                            },
                            onReject: {
                                // No action needed for delivered orders
                            }
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            refreshOrders()
        }
        .onAppear {
            refreshOrders()
            
            // Listen for customer info updates
            NotificationCenter.default.addObserver(
                forName: Notification.Name("CustomerInfoUpdated"),
                object: nil,
                queue: .main
            ) { notification in
                if let userInfo = notification.userInfo,
                   let orderId = userInfo["orderId"] as? String {
                    if let name = userInfo["customerName"] as? String {
                        customerNames[orderId] = name
                    }
                    if let phone = userInfo["customerPhone"] as? String {
                        customerPhones[orderId] = phone
                    }
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    private func refreshOrders() {
        isLoading = true
        loadDeliveredOrders()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
        }
    }
    
    private func fetchCustomerNames() {
        print("DEBUG: Fetching customer info for \(orders.count) delivered orders")
        let database = Database.database().reference()
        
        for order in orders {
            // Try with customerId first
            if !order.customerId.isEmpty {
                // Fetch both name and phone
                database.child("customers").child(order.customerId).observeSingleEvent(of: .value) { snapshot in
                    if let userData = snapshot.value as? [String: Any] {
                        // Handle name
                        if let fullName = userData["fullName"] as? String, !fullName.isEmpty {
                            DispatchQueue.main.async {
                                self.customerNames[order.id] = fullName
                            }
                        }
                        
                        // Handle phone
                        if let phone = userData["phone"] as? String, !phone.isEmpty {
                            DispatchQueue.main.async {
                                self.customerPhones[order.id] = phone
                            }
                        }
                    }
                }
            }
            
            // Also check users collection with userId if available
            database.child("orders").child(order.id).child("userId").observeSingleEvent(of: .value) { snapshot in
                if let userId = snapshot.value as? String, !userId.isEmpty {
                    // Try in users collection
                    database.child("users").child(userId).observeSingleEvent(of: .value) { userSnapshot in
                        if let userData = userSnapshot.value as? [String: Any] {
                            if let fullName = userData["fullName"] as? String, !fullName.isEmpty {
                                DispatchQueue.main.async {
                                    self.customerNames[order.id] = fullName
                                }
                            }
                            
                            if let phone = userData["phone"] as? String, !phone.isEmpty {
                                DispatchQueue.main.async {
                                    self.customerPhones[order.id] = phone
                                }
                            }
                        }
                    }
                }
            }
            
            // Also try in customers collection
            database.child("customers").child(order.userId).observeSingleEvent(of: .value) { customerSnapshot in
                if let userData = customerSnapshot.value as? [String: Any] {
                    if let fullName = userData["fullName"] as? String, !fullName.isEmpty {
                        DispatchQueue.main.async {
                            self.customerNames[order.id] = fullName
                        }
                    }
                    
                    if let phone = userData["phone"] as? String, !phone.isEmpty {
                        DispatchQueue.main.async {
                            self.customerPhones[order.id] = phone
                        }
                    }
                }
            }
        }
    }
    
    private func loadDeliveredOrders() {
        guard let restaurantId = authViewModel.currentUserId else {
            print("DEBUG: No restaurant ID available")
            return
        }
        
        print("DEBUG: Loading delivered orders for restaurant: \(restaurantId)")
        
        database.child("orders")
            .queryOrdered(byChild: "restaurantId")
            .queryEqual(toValue: restaurantId)
            .observe(.value) { snapshot in
                print("DEBUG: Restaurant query returned \(snapshot.childrenCount) orders")
                
                var deliveredOrders: [Order] = []
                
                for child in snapshot.children {
                    guard let snapshot = child as? DataSnapshot else { continue }
                    guard let dict = snapshot.value as? [String: Any] else { continue }
                    
                    let status = dict["status"] as? String ?? "unknown"
                    
                    if status == "delivered" {
                        if let order = Order(id: snapshot.key, data: dict) {
                            deliveredOrders.append(order)
                        }
                    }
                }
                
                print("DEBUG: Found \(deliveredOrders.count) delivered orders")
                
                DispatchQueue.main.async {
                    self.orders = deliveredOrders.sorted { $0.updatedAt ?? $0.createdAt > $1.updatedAt ?? $1.createdAt }
                    self.fetchCustomerNames()
                }
            }
    }
}

#Preview {
    RestaurantHomeView(authViewModel: AuthViewModel())
}
