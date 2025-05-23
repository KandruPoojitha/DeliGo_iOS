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
    let minPrice: Int
    let maxPrice: Int
    let rating: Double
    let numberOfRatings: Int
    let address: String
    let imageURL: String?
    let isOpen: Bool
    let latitude: Double
    let longitude: Double
    let discount: Int?
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
            // Restaurant image
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
            
            // Restaurant details
            VStack(alignment: .leading, spacing: 4) {
                // Name and status
                HStack {
                    Text(restaurant.name)
                        .font(.headline)
                    
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
                
                // Cuisine and price
                HStack {
                    Text(restaurant.cuisine)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Text(restaurant.priceRange)
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "F4A261"))
                            .fontWeight(.medium)
                        
                        if restaurant.minPrice > 0 || restaurant.maxPrice > 0 {
                            Text("$\(restaurant.minPrice)-\(restaurant.maxPrice)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // Rating
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
                
                // Distance and discount
                HStack {
                    // Distance
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
                    
                    Spacer()
                    
                    // Discount
                    if let discount = restaurant.discount, discount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("\(discount)% off")
                                .foregroundColor(.green)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        } else {
            return "\(Int(distance)) m"
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
                        if locationManager.location != nil {
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
            NavigationView {
                CustomerCartView(authViewModel: authViewModel)
            }
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
            
            // Account Tab (now last tab)
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
            print("DEBUG: Found \(children.count) restaurants in snapshot")
            
            for childSnapshot in children {
                guard let dict = childSnapshot.value as? [String: Any] else {
                    print("DEBUG: Failed to cast restaurant data to dictionary for key: \(childSnapshot.key)")
                    continue
                }

                // Check document status
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
                
                print("DEBUG: Processing approved restaurant: \(storeInfo["name"] ?? "unknown")")
                
                // Get discount value
                let discount = dict["discount"] as? Int
                if let discount = discount {
                    print("DEBUG: Found discount for restaurant: \(discount)%")
                }
                
                // Calculate average rating from ratingsandcomments
                var totalRating: Double = 0
                var numberOfRatings: Int = 0
                
                if let ratingsAndComments = dict["ratingsandcomments"] as? [String: Any],
                   let ratings = ratingsAndComments["rating"] as? [String: Any] {
                    for (_, rating) in ratings {
                        if let ratingValue = rating as? Double {
                            totalRating += ratingValue
                            numberOfRatings += 1
                        } else if let ratingValue = rating as? Int {
                            totalRating += Double(ratingValue)
                            numberOfRatings += 1
                        }
                    }
                }
                
                let averageRating = numberOfRatings > 0 ? totalRating / Double(numberOfRatings) : 0.0
                
                // Get location data
                var latitude: Double = 0
                var longitude: Double = 0
                
                if let location = dict["location"] as? [String: Any] {
                    latitude = location["latitude"] as? Double ?? 0
                    longitude = location["longitude"] as? Double ?? 0
                }
                
                // Get price range
                var minPrice: Int = 0
                var maxPrice: Int = 0
                var priceRangeString = "$"
                
                if let priceRange = storeInfo["price_range"] as? [String: Any] {
                    minPrice = priceRange["min"] as? Int ?? 0
                    maxPrice = priceRange["max"] as? Int ?? 0
                    
                    if maxPrice > 0 {
                        if maxPrice <= 15 {
                            priceRangeString = "$"
                        } else if maxPrice <= 30 {
                            priceRangeString = "$$"
                        } else if maxPrice <= 50 {
                            priceRangeString = "$$$"
                        } else {
                            priceRangeString = "$$$$"
                        }
                    }
                }

                let restaurant = Restaurant(
                    id: childSnapshot.key,
                    name: storeInfo["name"] as? String ?? "",
                    description: storeInfo["description"] as? String ?? "",
                    email: storeInfo["email"] as? String ?? "",
                    phone: storeInfo["phone"] as? String ?? "",
                    cuisine: storeInfo["cuisine"] as? String ?? "Various",
                    priceRange: priceRangeString,
                    minPrice: minPrice,
                    maxPrice: maxPrice,
                    rating: averageRating,
                    numberOfRatings: numberOfRatings,
                    address: storeInfo["address"] as? String ?? "",
                    imageURL: storeInfo["imageURL"] as? String,
                    isOpen: dict["isOpen"] as? Bool ?? false,
                    latitude: latitude,
                    longitude: longitude,
                    discount: discount,
                    distance: nil
                )

                print("DEBUG: Adding approved restaurant to list: \(restaurant.name)")
                loadedRestaurants.append(restaurant)
            }
            
            print("DEBUG: Loaded \(loadedRestaurants.count) approved restaurants")
            
            DispatchQueue.main.async {
                self.restaurants = loadedRestaurants
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
                    let distance = round(userLocation.distance(from: restaurantLocation))
                    restaurantsWithDistance[i].distance = distance
                } else {
                    restaurantsWithDistance[i].distance = nil
                }
            }
        } else {
            print("DEBUG: No user location available")
            for i in 0..<restaurantsWithDistance.count {
                restaurantsWithDistance[i].distance = nil
            }
        }
        
        DispatchQueue.main.async {
            print("DEBUG: Updating UI with \(restaurantsWithDistance.count) restaurants")
            self.restaurants = restaurantsWithDistance
            if !restaurantsWithDistance.isEmpty {
                self.sortRestaurants()
            }
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
                if $0.maxPrice == $1.maxPrice {
                    return $0.name < $1.name
                }
                return $0.maxPrice < $1.maxPrice
            }
            
        case .priceHighToLow:
            sortedRestaurants.sort {
                if $0.maxPrice == $1.maxPrice {
                    return $0.name < $1.name
                }
                return $0.maxPrice > $1.maxPrice
            }
        }
        
        self.restaurants = sortedRestaurants
        print("DEBUG: Sorted restaurants by \(sortOption.rawValue)")
    }
    
    private func getPriceValue(from priceRange: String) -> Int {
        return priceRange.filter { $0 == "$" }.count
    }
} 
