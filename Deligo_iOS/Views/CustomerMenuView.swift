import SwiftUI
import FirebaseDatabase

struct CustomerMenuView: View {
    @State private var menuItems: [MenuItem] = []
    @State private var searchText = ""
    @State private var showCustomizationSheet = false
    @State private var selectedMenuItem: MenuItem?
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
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(restaurant.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(restaurant.cuisine)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", restaurant.rating))
                        Text("(\(restaurant.numberOfRatings))")
                            .foregroundColor(.gray)
                        Text("•")
                        Text(restaurant.priceRange)
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
                                        CustomerMenuItemRow(item: item, onTap: {
                                            selectedMenuItem = item
                                            showCustomizationSheet = true
                                        }, authViewModel: authViewModel)
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
        .sheet(isPresented: $showCustomizationSheet) {
            if let item = selectedMenuItem {
                CustomerItemCustomizationView(
                    item: item,
                    isPresented: $showCustomizationSheet,
                    authViewModel: authViewModel
                )
            }
        }
        .onAppear {
            loadMenuItems()
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
                
                let options: [CustomizationOption] = customizationOptions.map { optionDict in
                    CustomizationOption(
                        id: optionDict["id"] as? String ?? "",
                        name: optionDict["name"] as? String ?? "",
                        type: CustomizationType(rawValue: optionDict["type"] as? String ?? "single") ?? .single,
                        required: optionDict["required"] as? Bool ?? false,
                        options: (optionDict["options"] as? [[String: Any]] ?? []).map { itemDict in
                            CustomizationItem(
                                id: itemDict["id"] as? String ?? "",
                                name: itemDict["name"] as? String ?? "",
                                price: itemDict["price"] as? Double ?? 0.0
                            )
                        },
                        maxSelections: optionDict["maxSelections"] as? Int ?? 1
                    )
                }
                
                let item = MenuItem(
                    id: id,
                    name: name,
                    description: description,
                    price: price,
                    imageURL: imageURL,
                    category: category,
                    isAvailable: isAvailable,
                    customizationOptions: options
                )
                items.append(item)
            }
            
            self.menuItems = items
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

struct CustomerMenuItemRow: View {
    let item: MenuItem
    let onTap: () -> Void
    @ObservedObject var authViewModel: AuthViewModel
    @State private var isFavorite = false
    
    init(item: MenuItem, onTap: @escaping () -> Void, authViewModel: AuthViewModel) {
        self.item = item
        self.onTap = onTap
        self.authViewModel = authViewModel
    }
    
    var body: some View {
        Button(action: onTap) {
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
                    toggleFavorite()
                }) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .red : .gray)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .onAppear {
            checkIfFavorite()
        }
    }
    
    private func checkIfFavorite() {
        guard let userId = authViewModel.currentUserId else { return }
        let db = Database.database().reference()
        
        db.child("users").child(userId).child("favorites").child(item.id).observeSingleEvent(of: .value) { snapshot in
            isFavorite = snapshot.exists()
        }
    }
    
    private func toggleFavorite() {
        guard let userId = authViewModel.currentUserId else { return }
        let db = Database.database().reference()
        let favoritesRef = db.child("users").child(userId).child("favorites").child(item.id)
        
        if isFavorite {
            // Remove from favorites
            favoritesRef.removeValue()
        } else {
            // Add to favorites
            let favoriteData: [String: Any] = [
                "id": item.id,
                "name": item.name,
                "description": item.description,
                "price": item.price,
                "imageURL": item.imageURL as Any,
                "category": item.category,
                "timestamp": ServerValue.timestamp()
            ]
            favoritesRef.setValue(favoriteData)
        }
        
        isFavorite.toggle()
    }
}

struct CustomerItemCustomizationView: View {
    let item: MenuItem
    @Binding var isPresented: Bool
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedOptions: [String: Set<String>] = [:]
    @State private var quantity = 1
    
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
        NavigationView {
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
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("$\(String(format: "%.2f", totalPrice))")
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            addToCart()
                            isPresented = false
                        }) {
                            Text("Add to Cart")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(width: 200)
                                .background(isValid ? Color(hex: "F4A261") : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(!isValid)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
            }
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
        // TODO: Implement add to cart functionality
        // This should add the item with its customizations to the user's cart
    }
}

struct SingleSelectionOptionView: View {
    let option: CustomizationOption
    let selectedIds: Set<String>
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(option.options) { item in
                Button(action: { onSelect(item.id) }) {
                    HStack {
                        Image(systemName: selectedIds.contains(item.id) ? "circle.fill" : "circle")
                            .foregroundColor(Color(hex: "F4A261"))
                        
                        Text(item.name)
                        
                        Spacer()
                        
                        if item.price > 0 {
                            Text("+$\(String(format: "%.2f", item.price))")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
        }
    }
}

struct MultipleSelectionOptionView: View {
    let option: CustomizationOption
    let selectedIds: Set<String>
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select up to \(option.maxSelections)")
                .font(.caption)
                .foregroundColor(.gray)
            
            ForEach(option.options) { item in
                Button(action: { onSelect(item.id) }) {
                    HStack {
                        Image(systemName: selectedIds.contains(item.id) ? "checkmark.square.fill" : "square")
                            .foregroundColor(Color(hex: "F4A261"))
                        
                        Text(item.name)
                        
                        Spacer()
                        
                        if item.price > 0 {
                            Text("+$\(String(format: "%.2f", item.price))")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
        }
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
            rating: 4.5,
            numberOfRatings: 100,
            address: "123 Test Street",
            imageURL: nil,
            isOpen: true
        ),
        authViewModel: AuthViewModel()
    )
} 