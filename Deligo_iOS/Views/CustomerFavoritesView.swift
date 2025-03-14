import SwiftUI
import FirebaseDatabase

struct CustomerFavoritesView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var favoriteItems: [MenuItem] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading favorites...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if favoriteItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Favorites Yet")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Items you favorite will appear here")
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(favoriteItems) { item in
                            NavigationLink(destination: ItemDetailView(item: item, authViewModel: authViewModel)) {
                                MenuItemRowView(item: item, authViewModel: authViewModel)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Favorites")
        }
        .onAppear {
            loadFavorites()
        }
    }
    
    private func loadFavorites() {
        guard let userId = authViewModel.currentUserId else {
            isLoading = false
            return
        }
        
        let db = Database.database().reference()
        db.child("customers").child(userId).child("favorites").observe(.value) { snapshot in
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
                
                loadFullMenuItemDetails(id: id) { updatedItem in
                    // Add the item with complete details
                    items.append(updatedItem)
                    
                    // Sort by most recently added
                    items.sort { (item1, item2) in
                        let timestamp1 = (snapshot.childSnapshot(forPath: item1.id).value as? [String: Any])?["timestamp"] as? Double ?? 0
                        let timestamp2 = (snapshot.childSnapshot(forPath: item2.id).value as? [String: Any])?["timestamp"] as? Double ?? 0
                        return timestamp1 > timestamp2
                    }
                    
                    DispatchQueue.main.async {
                        self.favoriteItems = items
                        self.isLoading = false
                    }
                }
            }
            
            // If no favorites, update UI immediately
            if snapshot.childrenCount == 0 {
                DispatchQueue.main.async {
                    self.favoriteItems = []
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadFullMenuItemDetails(id: String, completion: @escaping (MenuItem) -> Void) {
        let db = Database.database().reference()
        
        // Search for this menu item in all restaurants
        var foundItem = false
        var defaultItem = MenuItem(
            id: id,
            name: "",
            description: "",
            price: 0.0,
            imageURL: nil,
            category: "",
            isAvailable: true,
            customizationOptions: []
        )
        
        db.child("restaurants").observeSingleEvent(of: .value) { snapshot in
            // Create default item with basic info
            for favoriteItem in self.favoriteItems where favoriteItem.id == id {
                defaultItem = favoriteItem
                break
            }
            
            for restaurantChild in snapshot.children {
                guard let restaurantSnapshot = restaurantChild as? DataSnapshot else { continue }
                
                let menuItemRef = db.child("restaurants").child(restaurantSnapshot.key).child("menu_items").child(id)
                menuItemRef.observeSingleEvent(of: .value) { itemSnapshot in
                    if itemSnapshot.exists(), let dict = itemSnapshot.value as? [String: Any] {
                        foundItem = true
                        
                        let name = dict["name"] as? String ?? defaultItem.name
                        let description = dict["description"] as? String ?? defaultItem.description
                        let price = dict["price"] as? Double ?? defaultItem.price
                        let imageURL = dict["imageURL"] as? String ?? defaultItem.imageURL
                        let category = dict["category"] as? String ?? defaultItem.category
                        let isAvailable = dict["isAvailable"] as? Bool ?? true
                        let customizationOptions = dict["customizationOptions"] as? [[String: Any]] ?? []
                        
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
                        
                        completion(item)
                    }
                }
            }
            
            // After checking all restaurants, if item wasn't found, return default
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if !foundItem {
                    completion(defaultItem)
                }
            }
        }
    }
}

#Preview {
    CustomerFavoritesView(authViewModel: AuthViewModel())
} 