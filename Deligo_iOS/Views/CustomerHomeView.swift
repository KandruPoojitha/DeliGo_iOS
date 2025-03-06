import SwiftUI
import FirebaseDatabase

struct Restaurant: Identifiable {
    let id: String
    let name: String
    let description: String
    let email: String
    let phone: String
    let cuisine: String
    let priceRange: String
    let rating: Double
    let numberOfRatings: Int
    let address: String
    let imageURL: String?
    let isOpen: Bool
}

struct RestaurantRow: View {
    let restaurant: Restaurant
    
    var body: some View {
        HStack(spacing: 12) {
            if let imageURL = restaurant.imageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 80, height: 80)
                .cornerRadius(8)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 30))
                    .foregroundColor(.gray)
                    .frame(width: 80, height: 80)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.headline)
                Text(restaurant.cuisine)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text(String(format: "%.1f", restaurant.rating))
                        .font(.caption)
                    Text("(\(restaurant.numberOfRatings))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if !restaurant.isOpen {
                Text("Closed")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 8)
    }
}

struct MainCustomerView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var restaurants: [Restaurant] = []
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            NavigationView {
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search restaurants...", text: $searchText)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding()
                    
                    if filteredRestaurants.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "fork.knife")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No Restaurants Found")
                                .font(.title2)
                                .fontWeight(.medium)
                            Text("Try adjusting your filters")
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    } else {
                        List(filteredRestaurants) { restaurant in
                            NavigationLink(destination: CustomerMenuView(restaurant: restaurant, authViewModel: authViewModel)) {
                                RestaurantRow(restaurant: restaurant)
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                .navigationTitle("Restaurants")
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)
            
            // Favorites Tab
            CustomerFavoritesView(authViewModel: authViewModel)
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Favorites")
                }
                .tag(1)
            
            // Cart Tab
            CartView(authViewModel: authViewModel)
                .tabItem {
                    Image(systemName: "cart.fill")
                    Text("Cart")
                }
                .tag(2)
            
            // Orders Tab
            CustomerOrdersView(authViewModel: authViewModel)
                .tabItem {
                    Image(systemName: "list.bullet.rectangle.fill")
                    Text("Orders")
                }
                .tag(3)
            
            // Account Tab
            CustomerAccountView(authViewModel: authViewModel)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Account")
                }
                .tag(4)
        }
        .accentColor(Color(hex: "F4A261"))
        .onAppear {
            loadRestaurants()
        }
    }
    
    private var filteredRestaurants: [Restaurant] {
        if searchText.isEmpty {
            return restaurants
        }
        return restaurants.filter { restaurant in
            restaurant.name.localizedCaseInsensitiveContains(searchText) ||
            restaurant.cuisine.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func loadRestaurants() {
        print("DEBUG: Starting to load restaurants")
        let db = Database.database().reference()
        db.child("restaurants").observe(.value) { snapshot in
            print("DEBUG: Got Firebase snapshot")
            var loadedRestaurants: [Restaurant] = []
            
            let children = snapshot.children.allObjects as? [DataSnapshot] ?? []
            print("DEBUG: Found \(children.count) restaurants")
            
            for childSnapshot in children {
                guard let dict = childSnapshot.value as? [String: Any] else {
                    print("DEBUG: Failed to cast restaurant data to dictionary for key: \(childSnapshot.key)")
                    continue
                }

                print("DEBUG: Processing restaurant with ID: \(childSnapshot.key)")

                // Debugging to check structure
                if let documents = dict["documents"] as? [String: Any] {
                    print("DEBUG: Found documents node")
                    if let documentStatus = documents["status"] as? String {
                        print("DEBUG: Found document status -> \(documentStatus)")
                    } else {
                        print("DEBUG: Missing status in documents")
                    }
                } else {
                    print("DEBUG: Missing documents node")
                }

                // Corrected path to check document status
                guard let documents = dict["documents"] as? [String: Any],
                      let documentStatus = documents["status"] as? String,
                      documentStatus == "approved" else {
                    print("DEBUG: Restaurant not approved or missing document status")
                    continue
                }

                guard let storeInfo = dict["store_info"] as? [String: Any] else {
                    print("DEBUG: Missing or invalid store_info for restaurant: \(childSnapshot.key)")
                    continue
                }

                let restaurant = Restaurant(
                    id: childSnapshot.key,
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

                loadedRestaurants.append(restaurant)
                print("DEBUG: Added restaurant to loaded list: \(restaurant.name)")
            }

            // Sort restaurants by name
            loadedRestaurants.sort { $0.name < $1.name }
            
            DispatchQueue.main.async {
                self.restaurants = loadedRestaurants
                print("DEBUG: Updated UI with \(self.restaurants.count) restaurants")
            }
        }
    }
} 
