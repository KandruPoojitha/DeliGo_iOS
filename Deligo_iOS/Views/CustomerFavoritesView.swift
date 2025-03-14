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
            print("No user ID found")
            isLoading = false
            return
        }
        
        print("Loading favorites for user: \(userId)")
        let db = Database.database().reference()
        db.child("customers").child(userId).child("favorites").observeSingleEvent(of: .value) { snapshot in
            print("Favorites snapshot received: \(snapshot.childrenCount) items")
            
            // If no favorites, update UI immediately
            if snapshot.childrenCount == 0 {
                DispatchQueue.main.async {
                    self.favoriteItems = []
                    self.isLoading = false
                    print("No favorites found")
                }
                return
            }
            
            var items: [MenuItem] = []
            let group = DispatchGroup()
            
            for child in snapshot.children {
                guard let snapshot = child as? DataSnapshot else { 
                    print("Invalid snapshot")
                    continue 
                }
                
                let id = snapshot.key
                print("Processing favorite item with ID: \(id)")
                
                group.enter()
                loadFullMenuItemDetails(id: id) { updatedItem in
                    print("Loaded details for item: \(updatedItem.name)")
                    items.append(updatedItem)
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                print("All favorite items loaded: \(items.count)")
                self.favoriteItems = items
                self.isLoading = false
            }
        }
    }
    
    private func loadFullMenuItemDetails(id: String, completion: @escaping (MenuItem) -> Void) {
        let db = Database.database().reference()
        
        // First try to get the basic info from favorites
        db.child("customers").child(authViewModel.currentUserId ?? "").child("favorites").child(id).observeSingleEvent(of: .value) { snapshot in
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
            
            if let dict = snapshot.value as? [String: Any] {
                defaultItem = MenuItem(
                    id: id,
                    name: dict["name"] as? String ?? "",
                    description: dict["description"] as? String ?? "",
                    price: dict["price"] as? Double ?? 0.0,
                    imageURL: dict["imageURL"] as? String,
                    category: dict["category"] as? String ?? "",
                    isAvailable: true,
                    customizationOptions: []
                )
                print("Found basic info for item: \(defaultItem.name)")
            }
            
            // Now search for full details in all restaurants
            var foundFullItem = false
            
            db.child("restaurants").observeSingleEvent(of: .value) { snapshot in
                if snapshot.childrenCount == 0 {
                    print("No restaurants found")
                    completion(defaultItem)
                    return
                }
                
                let restaurantGroup = DispatchGroup()
                
                for restaurantChild in snapshot.children {
                    guard let restaurantSnapshot = restaurantChild as? DataSnapshot else { continue }
                    let restaurantId = restaurantSnapshot.key
                    
                    restaurantGroup.enter()
                    let menuItemRef = db.child("restaurants").child(restaurantId).child("menu_items").child(id)
                    menuItemRef.observeSingleEvent(of: .value) { itemSnapshot in
                        defer { restaurantGroup.leave() }
                        
                        if itemSnapshot.exists(), let dict = itemSnapshot.value as? [String: Any] {
                            foundFullItem = true
                            
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
                            
                            print("Found full details for menu item: \(name) in restaurant: \(restaurantId)")
                            completion(item)
                        }
                    }
                }
                
                restaurantGroup.notify(queue: .main) {
                    if !foundFullItem {
                        print("Menu item not found in any restaurant: \(id), using basic info")
                        completion(defaultItem)
                    }
                }
            }
        }
    }
}

#Preview {
    CustomerFavoritesView(authViewModel: AuthViewModel())
} 