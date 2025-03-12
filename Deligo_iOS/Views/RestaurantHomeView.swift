import SwiftUI
import FirebaseDatabase

struct RestaurantHomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    @State private var selectedOrderTab = 0
    @State private var isRestaurantOpen = false
    @State private var restaurant: Restaurant?
    
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
            case .rejected:
                VStack(spacing: 20) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("Documents Rejected")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Your documents were rejected. Please submit new documents.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    Button(action: {
                        authViewModel.documentStatus = .notSubmitted
                    }) {
                        Text("Submit New Documents")
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "F4A261"))
                            .cornerRadius(12)
                    }
                }
                .padding()
            case .approved:
                if let restaurant = restaurant {
                    TabView(selection: $selectedTab) {
                        // Orders Tab
                        OrdersTabView(selectedOrderTab: $selectedOrderTab, isRestaurantOpen: $isRestaurantOpen)
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
            }
        }
        .onChange(of: isRestaurantOpen) { oldValue, newValue in
            updateRestaurantStatus(isOpen: newValue)
        }
    }
    
    private func loadRestaurantData() {
        guard let userId = authViewModel.currentUserId else {
            print("DEBUG: No user ID found")
            return
        }
        
        let db = Database.database().reference()
        
        // First check if this user is a restaurant
        db.child("restaurants").child(userId).child("role").observeSingleEvent(of: .value) { snapshot in
            guard let role = snapshot.value as? String,
                  role == "Restaurant" else {
                print("DEBUG: User is not a restaurant. Role: \(snapshot.value as? String ?? "nil")")
                return
            }
            
            // Now load the restaurant data
            db.child("restaurants").child(userId).observeSingleEvent(of: .value) { snapshot in
                print("DEBUG: Checking restaurant data for userId: \(userId)")
                guard let dict = snapshot.value as? [String: Any] else {
                    print("DEBUG: Could not parse restaurant data")
                    return
                }
                
                // Check documents/status path
                guard let documents = dict["documents"] as? [String: Any],
                      let status = documents["status"] as? String else {
                    print("DEBUG: Could not find status in documents/status path")
                    return
                }
                
                print("DEBUG: Found status: \(status)")
                
                guard status == "approved" else {
                    print("DEBUG: Restaurant not approved. Status: \(status)")
                    return
                }
                
                guard let storeInfo = dict["store_info"] as? [String: Any] else {
                    print("DEBUG: Missing store info")
                    return
                }
                
                print("DEBUG: Found approved restaurant with name: \(storeInfo["name"] as? String ?? "unknown")")
                
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
                    isOpen: dict["isOpen"] as? Bool ?? false
                )
                print("DEBUG: Successfully loaded restaurant data")
            }
        }
    }
    
    private func updateRestaurantStatus(isOpen: Bool) {
        guard let userId = authViewModel.currentUserId else { return }
        let db = Database.database().reference()
        
        db.child("restaurants").child(userId).updateChildValues([
            "isOpen": isOpen
        ]) { error, _ in
            if let error = error {
                print("Error updating restaurant status: \(error.localizedDescription)")
            }
        }
    }
}

struct OrdersTabView: View {
    @Binding var selectedOrderTab: Int
    @Binding var isRestaurantOpen: Bool
    @ObservedObject private var appSettings = AppSettings.shared
    
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
                        .toggleStyle(SwitchToggleStyle(tint: isRestaurantOpen ? .green : .red))
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
                    NewOrdersView()
                        .tag(0)
                    
                    InProgressOrdersView()
                        .tag(1)
                    
                    DeliveredOrdersView()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                Spacer()
            }
            .background(appSettings.isDarkMode ? Color.black : Color(.systemGroupedBackground))
            .edgesIgnoringSafeArea(.all)
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
    var body: some View {
        VStack {
            if true { // Replace with actual empty state check
                VStack(spacing: 16) {
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No Orders Yet")
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("New orders will appear here")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
        }
    }
}

struct InProgressOrdersView: View {
    var body: some View {
        VStack {
            if true { // Replace with actual empty state check
                VStack(spacing: 16) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No Orders In Progress")
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("Orders being prepared will appear here")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
        }
    }
}

struct DeliveredOrdersView: View {
    var body: some View {
        VStack {
            if true { // Replace with actual empty state check
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No Delivered Orders")
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("Completed orders will appear here")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
        }
    }
}

#Preview {
    RestaurantHomeView(authViewModel: AuthViewModel())
}
