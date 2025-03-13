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
        // Validate coordinates are within Ottawa area (approximately)
        let ottawaMinLat = 45.0
        let ottawaMaxLat = 45.8
        let ottawaMinLon = -76.0
        let ottawaMaxLon = -75.0
        
        if latitude >= ottawaMinLat && latitude <= ottawaMaxLat &&
           longitude >= ottawaMinLon && longitude <= ottawaMaxLon {
            print("""
                DEBUG: Valid Ottawa coordinates for \(name):
                - Latitude: \(latitude)
                - Longitude: \(longitude)
                """)
            return CLLocation(latitude: latitude, longitude: longitude)
        }
        print("""
            DEBUG: Coordinates outside Ottawa area for \(name):
            - Latitude: \(latitude)
            - Longitude: \(longitude)
            - Expected range: lat [45.0, 45.8], lon [-76.0, -75.0]
            """)
        return nil
    }
    
    func calculateDistance(from userLocation: CLLocation) -> Double? {
        guard let restaurantLocation = location else { return nil }
        
        // Use direct CLLocation distance calculation
        let distance = userLocation.distance(from: restaurantLocation)
        print("""
            DEBUG: Distance calculation for \(name):
            - User: (\(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude))
            - Restaurant: (\(latitude), \(longitude))
            - Raw distance: \(distance)m (\(distance/1000.0)km)
            """)
        return distance
    }
}

// Add extension for degree to radian conversion
extension Double {
    var degreesToRadians: Double {
        return self * .pi / 180
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
                
                if let distance = restaurant.distance {
                    HStack(spacing: 2) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(formatDistance(distance))
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
            return String(format: "%.0f m away", distance)
        } else {
            let kilometers = distance / 1000.0
            if kilometers < 100 {
                // For distances under 100 km, show one decimal place
                return String(format: "%.1f km away", kilometers)
            } else {
                // For longer distances, show no decimal places
                return String(format: "%.0f km away", kilometers)
            }
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
                    
                    // Location indicator (uncomment for debugging)
                    if let location = locationManager.location {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(Color(hex: "F4A261"))
                            Text("Your location: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    
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
            locationManager.requestLocationPermission()
            locationManager.startUpdatingLocation()
            loadRestaurants()
        }
        .onChange(of: locationManager.location) { _, newLocation in
            print("DEBUG: Location changed in view - updating distances")
            if let location = newLocation {
                print("DEBUG: New location available: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
                updateDistances(for: restaurants)
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
                    print("DEBUG: Restaurant not approved or missing document status")
                    continue
                }

                guard let storeInfo = dict["store_info"] as? [String: Any] else {
                    print("DEBUG: Missing or invalid store_info for restaurant: \(childSnapshot.key)")
                    continue
                }
                
                // Get and validate location data
                var latitude: Double = 0
                var longitude: Double = 0
                
                if let location = dict["location"] as? [String: Any],
                   let lat = location["latitude"] as? Double,
                   let lon = location["longitude"] as? Double,
                   lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 {
                    latitude = lat
                    longitude = lon
                    print("DEBUG: Valid coordinates found for \(storeInfo["name"] as? String ?? "") - lat: \(latitude), lon: \(longitude)")
                } else {
                    print("DEBUG: Invalid or missing coordinates for restaurant: \(childSnapshot.key)")
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

                loadedRestaurants.append(restaurant)
                print("DEBUG: Added restaurant to loaded list: \(restaurant.name) with coordinates: (\(latitude), \(longitude))")
            }
            
            DispatchQueue.main.async {
                self.updateDistances(for: loadedRestaurants)
            }
        }
    }
    
    private func updateDistances(for restaurants: [Restaurant]) {
        print("DEBUG: Starting distance updates for \(restaurants.count) restaurants")
        var restaurantsWithDistance = restaurants
        
        if let userLocation = locationManager.location {
            print("""
                DEBUG: Updating distances with user location:
                - User coordinates: (\(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude))
                - User accuracy: \(userLocation.horizontalAccuracy)m
                - Location timestamp: \(userLocation.timestamp)
                - Is simulator: \(isSimulator())
                """)
            
            // Check if user location is reasonable for Ottawa area
            let ottawaMinLat = 45.0
            let ottawaMaxLat = 45.8
            let ottawaMinLon = -76.0
            let ottawaMaxLon = -75.0
            
            let isInOttawa = userLocation.coordinate.latitude >= ottawaMinLat &&
                            userLocation.coordinate.latitude <= ottawaMaxLat &&
                            userLocation.coordinate.longitude >= ottawaMinLon &&
                            userLocation.coordinate.longitude <= ottawaMaxLon
            
            if !isInOttawa {
                print("""
                    DEBUG: ⚠️ User location is outside Ottawa area:
                    - Current: (\(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude))
                    - Expected: lat [45.0, 45.8], lon [-76.0, -75.0]
                    - Please set simulator location to Ottawa area
                    """)
            }
            
            for i in 0..<restaurantsWithDistance.count {
                let restaurant = restaurantsWithDistance[i]
                if let distance = restaurant.calculateDistance(from: userLocation) {
                    restaurantsWithDistance[i].distance = distance
                    print("""
                        DEBUG: Distance calculation successful for \(restaurant.name):
                        - Distance: \(formatDistance(distance))
                        """)
                }
            }
            
            print("DEBUG: Finished calculating distances, updating restaurants array")
            DispatchQueue.main.async {
                self.restaurants = restaurantsWithDistance
                self.sortRestaurants()
            }
        } else {
            print("DEBUG: No user location available - Location services might be disabled")
            DispatchQueue.main.async {
                self.restaurants = restaurantsWithDistance
            }
        }
    }
    
    private func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    private func sortRestaurants() {
        print("DEBUG: Sorting restaurants by \(sortOption)")
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
            sortedRestaurants.sort { 
                let price1 = getPriceValue(from: $0.priceRange)
                let price2 = getPriceValue(from: $1.priceRange)
                
                if price1 == price2 {
                    // If prices are equal, sort by name
                    return $0.name < $1.name
                }
                
                return price2 < price1
            }
        }
        
        print("DEBUG: Sorted restaurants:")
        for restaurant in sortedRestaurants {
            if let distance = restaurant.distance {
                print("DEBUG: \(restaurant.name) - \(formatDistance(distance))")
            } else {
                print("DEBUG: \(restaurant.name) - No distance available")
            }
        }
        
        self.restaurants = sortedRestaurants
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return String(format: "%.0f m away", distance)
        } else {
            let kilometers = distance / 1000.0
            if kilometers < 100 {
                // For distances under 100 km, show one decimal place
                return String(format: "%.1f km away", kilometers)
            } else {
                // For longer distances, show no decimal places
                return String(format: "%.0f km away", kilometers)
            }
        }
    }
    
    private func getPriceValue(from priceRange: String) -> Int {
        return priceRange.filter { $0 == "$" }.count
    }
} 
