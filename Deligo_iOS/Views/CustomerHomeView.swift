import SwiftUI
import FirebaseDatabase
import CoreLocation

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
    let latitude: Double
    let longitude: Double
    var distance: Double?
    
    var location: CLLocation? {
        // More lenient validation - only return nil if coordinates are clearly invalid
        if latitude == 0 && longitude == 0 {
            return nil
        }
        // Validate coordinates are within reasonable bounds
        if abs(latitude) <= 90 && abs(longitude) <= 180 {
            return CLLocation(latitude: latitude, longitude: longitude)
        }
        return nil
    }
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
                
                HStack {
                    Text(restaurant.cuisine)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text(restaurant.priceRange)
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "F4A261"))
                        .fontWeight(.medium)
                }
                
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
                
                HStack(spacing: 2) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                    if let distance = restaurant.distance {
                        Text(formatDistance(distance))
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text("Distance unavailable")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
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
        }
        .padding(.vertical, 8)
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return "\(Int(round(distance)))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
}

struct MainCustomerView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var locationManager = CustomLocationManager()
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var restaurants: [Restaurant] = []
    @State private var sortOption: SortOption = .distance
    @State private var showingLocationAlert = false
    
    enum SortOption: String, CaseIterable, Identifiable {
        case distance = "Distance"
        case priceLowToHigh = "Price: Low to High"
        case priceHighToLow = "Price: High to Low"
        
        var id: String { self.rawValue }
    }
    
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
                    
                    // Location Status
                    HStack {
                        Image(systemName: locationManager.location != nil ? "location.fill" : "location.slash.fill")
                            .foregroundColor(locationManager.location != nil ? Color(hex: "F4A261") : .red)
                        if let location = locationManager.location {
                            Text("Location found")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else if let error = locationManager.locationError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .onTapGesture {
                                    showingLocationAlert = true
                                }
                        } else {
                            Text("Waiting for location...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    // Sort Options
                    HStack {
                        Text("Sort by:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Picker("Sort by", selection: $sortOption) {
                            ForEach(SortOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .accentColor(Color(hex: "F4A261"))
                        .onChange(of: sortOption) { _, _ in
                            sortRestaurants()
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                    
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
                        .refreshable {
                            // Manually refresh data
                            locationManager.startUpdatingLocation()
                            loadRestaurants()
                        }
                    }
                }
                .navigationTitle("Restaurants")
                .alert("Location Services Required", isPresented: $showingLocationAlert) {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Please enable location services in your device settings to see restaurant distances.")
                }
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
            CustomerCartView(authViewModel: authViewModel)
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
            print("DEBUG: MainCustomerView appeared")
            locationManager.checkLocationAuthorization()
            loadRestaurants()
            
            // Add notification observer for location updates
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("LocationUpdated"),
                object: nil,
                queue: .main) { _ in
                    print("DEBUG: Received location updated notification")
                    updateDistances(for: restaurants)
                }
        }
        .onChange(of: locationManager.location) { _, newLocation in
            // Recalculate distances when location updates
            print("DEBUG: Location changed to: \(String(describing: newLocation?.coordinate))")
            updateDistances(for: restaurants)
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            print("DEBUG: Authorization status changed to: \(newStatus.rawValue)")
            if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                locationManager.startUpdatingLocation()
            }
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

                // Corrected path to check document status
                guard let documents = dict["documents"] as? [String: Any],
                      let documentStatus = documents["status"] as? String,
                      documentStatus == "approved" else {
                    print("DEBUG: Restaurant \(childSnapshot.key) not approved or missing documents")
                    continue
                }

                guard let storeInfo = dict["store_info"] as? [String: Any] else {
                    print("DEBUG: Missing or invalid store_info for restaurant: \(childSnapshot.key)")
                    continue
                }
                
                // Get location data from the "location" node
                var latitude: Double = 0
                var longitude: Double = 0
                
                if let location = dict["location"] as? [String: Any] {
                    latitude = location["latitude"] as? Double ?? 0
                    longitude = location["longitude"] as? Double ?? 0
                    print("DEBUG: Found location data for restaurant \(storeInfo["name"] ?? ""): lat=\(latitude), lon=\(longitude)")
                } else {
                    print("DEBUG: No location data found for restaurant: \(storeInfo["name"] ?? "")")
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
                    isOpen: dict["isOpen"] as? Bool ?? false,
                    latitude: latitude,
                    longitude: longitude,
                    distance: nil
                )

                // Debug print restaurant location
                if let loc = restaurant.location {
                    print("DEBUG: Restaurant \(restaurant.name) has valid location: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
                } else {
                    print("DEBUG: Restaurant \(restaurant.name) has no valid location")
                }

                loadedRestaurants.append(restaurant)
            }
            
            print("DEBUG: Loaded \(loadedRestaurants.count) valid restaurants")
            
            DispatchQueue.main.async {
                self.updateDistances(for: loadedRestaurants)
            }
        }
    }
    
    private func updateDistances(for restaurants: [Restaurant]) {
        print("DEBUG: Updating distances with location: \(String(describing: locationManager.location))")
        var restaurantsWithDistance = restaurants
        
        if let userLocation = locationManager.location {
            print("DEBUG: User location found: \(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)")
            for i in 0..<restaurantsWithDistance.count {
                if let restaurantLocation = restaurantsWithDistance[i].location {
                    print("DEBUG: Calculating distance for \(restaurantsWithDistance[i].name)")
                    print("DEBUG: Restaurant location: \(restaurantLocation.coordinate.latitude), \(restaurantLocation.coordinate.longitude)")
                    
                    // Calculate distance and round to nearest meter
                    let distance = round(userLocation.distance(from: restaurantLocation))
                    print("DEBUG: Calculated distance for \(restaurantsWithDistance[i].name): \(distance) meters")
                    restaurantsWithDistance[i].distance = distance
                } else {
                    print("DEBUG: No valid location for restaurant: \(restaurantsWithDistance[i].name)")
                    restaurantsWithDistance[i].distance = nil
                }
            }
        } else {
            print("DEBUG: No user location available")
            // Request location update if not available
            locationManager.startUpdatingLocation()
            for i in 0..<restaurantsWithDistance.count {
                restaurantsWithDistance[i].distance = nil
            }
        }
        
        DispatchQueue.main.async {
            print("DEBUG: Updating UI with \(restaurantsWithDistance.count) restaurants")
            self.restaurants = restaurantsWithDistance
            self.sortRestaurants()
        }
    }
    
    private func sortRestaurants() {
        var sortedRestaurants = restaurants
        
        switch sortOption {
        case .distance:
            sortedRestaurants.sort {
                let dist1 = $0.distance ?? Double.infinity
                let dist2 = $1.distance ?? Double.infinity
                
                if dist1 == Double.infinity && dist2 == Double.infinity {
                    // If both distances are unknown, sort by name
                    return $0.name < $1.name
                }
                
                return dist1 < dist2
            }
            
        case .priceLowToHigh:
            sortedRestaurants.sort {
                let price1 = getPriceValue(from: $0.priceRange)
                let price2 = getPriceValue(from: $1.priceRange)
                
                if price1 == price2 {
                    // If prices are equal, sort by name
                    return $0.name < $1.name
                }
                
                return price1 < price2
            }
            
        case .priceHighToLow:
            // Sort by price range (high to low)
            sortedRestaurants.sort {
                let price1 = getPriceValue(from: $0.priceRange)
                let price2 = getPriceValue(from: $1.priceRange)
                
                if price1 == price2 {
                    // If prices are equal, sort by name
                    return $0.name < $1.name
                }
                
                return price1 > price2
            }
        }
        
        self.restaurants = sortedRestaurants
        print("DEBUG: Sorted restaurants by \(sortOption.rawValue)")
    }
    
    private func getPriceValue(from priceRange: String) -> Int {
        return priceRange.filter { $0 == "$" }.count
    }
} 
