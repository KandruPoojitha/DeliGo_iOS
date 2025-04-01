import SwiftUI
import FirebaseDatabase
import Foundation

struct CustomerMenuView: View {
    @State private var menuItems: [MenuItem] = []
    @State private var searchText = ""
    @State private var openingHours: String?
    @State private var closingHours: String?
    @State private var isRestaurantOpen: Bool = false
    @ObservedObject var authViewModel: AuthViewModel
    let restaurant: Restaurant
    
    init(restaurant: Restaurant, authViewModel: AuthViewModel) {
        self.restaurant = restaurant
        self.authViewModel = authViewModel
    }
    
    var filteredMenuItems: [MenuItem] {
        if searchText.isEmpty {
            return menuItems
        }
        return menuItems.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText) ||
            item.description.localizedCaseInsensitiveContains(searchText) ||
            item.category.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var groupedMenuItems: [String: [MenuItem]] {
        Dictionary(grouping: filteredMenuItems) { $0.category }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Restaurant Info Header
            VStack(alignment: .leading, spacing: 8) {
                if let imageURL = restaurant.imageURL {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(height: 200)
                    .clipped()
                } else {
                    Color.gray.opacity(0.3)
                        .frame(height: 200)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(restaurant.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(restaurant.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.vertical, 2)
                    
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                        Text(restaurant.address)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    if let opening = openingHours, let closing = closingHours {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.gray)
                            Text("\(opening) - \(closing)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    
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
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", restaurant.rating))
                        Text("(\(restaurant.numberOfRatings))")
                            .foregroundColor(.gray)
                            
                        Spacer()
                            
                        NavigationLink(destination: RestaurantCommentsView(restaurantId: restaurant.id)) {
                            HStack {
                                Image(systemName: "bubble.left.fill")
                                Text("View Reviews")
                            }
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "F4A261"))
                        }
                    }
                    .font(.subheadline)
                }
                .padding()
            }
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search menu items...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding()
            
            if menuItems.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "fork.knife")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No Menu Items Available")
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("Check back later")
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if filteredMenuItems.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Results")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Try searching for something else")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                            ForEach(groupedMenuItems.keys.sorted(), id: \.self) { category in
                                Section(header: CategoryHeader(title: category)) {
                                    ForEach(groupedMenuItems[category] ?? []) { item in
                                        NavigationLink(destination: ItemDetailView(item: item, authViewModel: authViewModel)) {
                                            MenuItemRowView(item: item, authViewModel: authViewModel)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadMenuItems()
            loadStoreHours()
        }
    }
    
    private func loadMenuItems() {
        let db = Database.database().reference()
        
        db.child("restaurants").child(restaurant.id).child("menu_items").observe(.value) { snapshot in
            var items: [MenuItem] = []
            
            for child in snapshot.children {
                guard let snapshot = child as? DataSnapshot,
                      let dict = snapshot.value as? [String: Any] else { continue }
                
                let id = snapshot.key
                let name = dict["name"] as? String ?? ""
                let description = dict["description"] as? String ?? ""
                let price = dict["price"] as? Double ?? 0.0
                let imageURL = dict["imageURL"] as? String
                let category = dict["category"] as? String ?? ""
                let isAvailable = dict["isAvailable"] as? Bool ?? true
                let customizationOptions = dict["customizationOptions"] as? [[String: Any]] ?? []
                
                if !isAvailable { continue } // Skip unavailable items for customers
                
                let menuItem = MenuItem(
                    id: id,
                    restaurantId: restaurant.id,
                    name: name,
                    description: description,
                    price: price,
                    imageURL: imageURL,
                    category: category,
                    isAvailable: isAvailable,
                    customizationOptions: customizationOptions.map { optionDict in
                        CustomizationOption(
                            id: optionDict["id"] as? String ?? UUID().uuidString,
                            name: optionDict["name"] as? String ?? "",
                            type: CustomizationType(rawValue: optionDict["type"] as? String ?? "single") ?? .single,
                            required: optionDict["required"] as? Bool ?? false,
                            options: (optionDict["options"] as? [[String: Any]] ?? []).map { itemDict in
                                CustomizationItem(
                                    id: itemDict["id"] as? String ?? UUID().uuidString,
                                    name: itemDict["name"] as? String ?? "",
                                    price: itemDict["price"] as? Double ?? 0.0
                                )
                            },
                            maxSelections: optionDict["maxSelections"] as? Int ?? 1
                        )
                    }
                )
                items.append(menuItem)
            }
            
            self.menuItems = items
        }
    }
    
    private func loadStoreHours() {
        let db = Database.database().reference()
        db.child("restaurants").child(restaurant.id).child("hours").observeSingleEvent(of: .value) { snapshot in
            if let value = snapshot.value as? [String: Any] {
                self.openingHours = value["opening"] as? String
                self.closingHours = value["closing"] as? String
                self.isRestaurantOpen = value["isOpen"] as? Bool ?? false
            }
        }
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return String(format: "%.0f meters away", distance)
        } else {
            return String(format: "%.1f km away", distance / 1000)
        }
    }
}

struct ItemDetailView: View {
    let item: MenuItem
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedOptions: [String: Set<String>] = [:]
    @State private var quantity = 1
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var specialInstructions: String = ""
    @ObservedObject var cartManager: CartManager
    
    init(item: MenuItem, authViewModel: AuthViewModel) {
        self.item = item
        self.authViewModel = authViewModel
        self._cartManager = ObservedObject(wrappedValue: CartManager(userId: authViewModel.currentUserId ?? ""))
    }
    
    var totalPrice: Double {
        let basePrice = item.price * Double(quantity)
        let customizationPrice = selectedOptions.flatMap { (_, selectedIds) in
            item.customizationOptions.flatMap { option in
                option.options.filter { selectedIds.contains($0.id) }
            }
        }.reduce(0.0) { $0 + $1.price }
        return basePrice + (customizationPrice * Double(quantity))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Item Image and Basic Info
                if let imageURL = item.imageURL {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(height: 200)
                    .clipped()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(item.description)
                        .font(.body)
                        .foregroundColor(.gray)
                    
                    Text("$\(String(format: "%.2f", item.price))")
                        .font(.headline)
                        .foregroundColor(Color(hex: "F4A261"))
                }
                .padding(.horizontal)
                
                // Quantity Selector
                HStack {
                    Text("Quantity")
                        .font(.headline)
                    Spacer()
                    Button(action: { if quantity > 1 { quantity -= 1 } }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(Color(hex: "F4A261"))
                    }
                    Text("\(quantity)")
                        .font(.headline)
                        .padding(.horizontal)
                    Button(action: { quantity += 1 }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(hex: "F4A261"))
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Customization Options
                if !item.customizationOptions.isEmpty {
                    Text("Customize Your Order")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
                
                ForEach(item.customizationOptions) { option in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(option.name)
                                .font(.headline)
                            if option.required {
                                Text("Required")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        if option.type == .single {
                            SingleSelectionOptionView(
                                option: option,
                                selectedIds: selectedOptions[option.id] ?? []
                            ) { selectedId in
                                selectedOptions[option.id] = [selectedId]
                            }
                        } else {
                            MultipleSelectionOptionView(
                                option: option,
                                selectedIds: selectedOptions[option.id] ?? []
                            ) { selectedId in
                                var currentSelection = selectedOptions[option.id] ?? []
                                if currentSelection.contains(selectedId) {
                                    currentSelection.remove(selectedId)
                                } else if currentSelection.count < option.maxSelections {
                                    currentSelection.insert(selectedId)
                                }
                                selectedOptions[option.id] = currentSelection
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // Special Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Special Instructions")
                        .font(.headline)
                    
                    TextField("Add any special requests here...", text: $specialInstructions, axis: .vertical)
                        .padding()
                        .frame(minHeight: 80)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .lineLimit(3...5)
                }
                .padding(.horizontal)
                
                // Add to Cart Button
                Button(action: {
                    addToCart()
                }) {
                    Text("Add to Cart - $\(String(format: "%.2f", totalPrice))")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isValid ? Color(hex: "F4A261") : Color.gray)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .disabled(!isValid)
                .padding(.vertical)
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Cart", isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage.contains("successfully") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isValid: Bool {
        // Check if all required options are selected
        for option in item.customizationOptions where option.required {
            guard let selectedIds = selectedOptions[option.id], !selectedIds.isEmpty else {
                return false
            }
        }
        return true
    }
    
    private func addToCart() {
        guard authViewModel.currentUserId != nil else {
            alertMessage = "Error: User not logged in"
            showingAlert = true
            return
        }
        
        // Create customization selections
        var customizations: [String: [CustomizationSelection]] = [:]
        for option in item.customizationOptions {
            let selectedIds = selectedOptions[option.id] ?? []
            let selectedItems = option.options
                .filter { selectedIds.contains($0.id) }
                .map { SelectedItem(id: $0.id, name: $0.name, price: $0.price) }
            
            if !selectedItems.isEmpty {
                let selection = CustomizationSelection(
                    optionId: option.id,
                    optionName: option.name,
                    selectedItems: selectedItems
                )
                customizations[option.id] = [selection]
            }
        }
        
        // Create cart item
        let cartItem = CartItem(
            id: UUID().uuidString,
            menuItemId: item.id,
            restaurantId: item.restaurantId,
            name: item.name,
            description: item.description,
            price: item.price,
            imageURL: item.imageURL,
            quantity: quantity,
            customizations: customizations,
            specialInstructions: specialInstructions.trimmingCharacters(in: .whitespacesAndNewlines),
            totalPrice: totalPrice
        )
        
        cartManager.addToCart(item: cartItem)
        alertMessage = "Item added to cart successfully!"
        showingAlert = true
    }
}

struct MenuItemRowView: View {
    let item: MenuItem
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var favoritesManager: FavoritesManager
    @State private var isFavorite = false
    
    init(item: MenuItem, authViewModel: AuthViewModel) {
        self.item = item
        self.authViewModel = authViewModel
        self._favoritesManager = ObservedObject(wrappedValue: FavoritesManager(userId: authViewModel.currentUserId ?? ""))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let imageURL = item.imageURL {
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
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(item.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                
                HStack {
                    Text("$\(String(format: "%.2f", item.price))")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "F4A261"))
                    
                    if !item.customizationOptions.isEmpty {
                        Text("•")
                        Text("Customizable")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                favoritesManager.toggleFavorite(item: item)
                isFavorite.toggle()
            }) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(isFavorite ? .red : .gray)
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 8)
        .onAppear {
            isFavorite = favoritesManager.isFavorite(itemId: item.id)
        }
    }
}

struct CategoryHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.title3)
            .fontWeight(.bold)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
    }
}

#Preview {
    CustomerMenuView(
        restaurant: Restaurant(
            id: "1",
            name: "Test Restaurant",
            description: "A test restaurant description",
            email: "test@example.com",
            phone: "123-456-7890",
            cuisine: "Various",
            priceRange: "$$",
            minPrice: 10,
            maxPrice: 30,
            rating: 4.5,
            numberOfRatings: 100,
            address: "123 Test Street",
            imageURL: nil,
            isOpen: true,
            latitude: 43.651070,  // Toronto coordinates for preview
            longitude: -79.347015,
            distance: 1500  // 1.5 km
        ),
        authViewModel: AuthViewModel()
    )
}