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
                                        CustomerMenuItemRow(
                                            item: item,
                                            onTap: {
                                                selectedMenuItem = item
                                                showCustomizationSheet = true
                                            },
                                            authViewModel: authViewModel
                                        )
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