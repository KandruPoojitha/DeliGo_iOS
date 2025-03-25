import Foundation
import FirebaseDatabase

class FavoritesManager: ObservableObject {
    @Published var favoriteItems: [MenuItem] = []
    private let db = Database.database().reference()
    private let userId: String
    
    init(userId: String) {
        self.userId = userId
        loadFavorites()
    }
    
    func loadFavorites() {
        db.child("customers").child(userId).child("favorites").observe(.value) { [weak self] snapshot in
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
                let customizationOptionsData = dict["customizationOptions"] as? [[String: Any]] ?? []
                
                // Parse customization options
                let customizationOptions: [CustomizationOption] = customizationOptionsData.map { optionDict in
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
                    customizationOptions: customizationOptions
                )
                items.append(item)
            }
            
            // Sort by most recently added
            items.sort { (item1, item2) in
                let timestamp1 = (snapshot.childSnapshot(forPath: item1.id).value as? [String: Any])?["timestamp"] as? Double ?? 0
                let timestamp2 = (snapshot.childSnapshot(forPath: item2.id).value as? [String: Any])?["timestamp"] as? Double ?? 0
                return timestamp1 > timestamp2
            }
            
            DispatchQueue.main.async {
                self?.favoriteItems = items
            }
        }
    }
    
    func addToFavorites(item: MenuItem) {
        // Convert customization options to dictionary format
        let customizationOptionsData: [[String: Any]] = item.customizationOptions.map { option in
            [
                "id": option.id,
                "name": option.name,
                "type": option.type.rawValue,
                "required": option.required,
                "maxSelections": option.maxSelections,
                "options": option.options.map { item in
                    [
                        "id": item.id,
                        "name": item.name,
                        "price": item.price
                    ]
                }
            ]
        }
        
        let favoriteData: [String: Any] = [
            "id": item.id,
            "name": item.name,
            "description": item.description,
            "price": item.price,
            "imageURL": item.imageURL as Any,
            "category": item.category,
            "isAvailable": item.isAvailable,
            "customizationOptions": customizationOptionsData,
            "timestamp": ServerValue.timestamp()
        ]
        
        db.child("customers").child(userId).child("favorites").child(item.id).setValue(favoriteData)
    }
    
    func removeFromFavorites(itemId: String) {
        db.child("customers").child(userId).child("favorites").child(itemId).removeValue()
    }
    
    func isFavorite(itemId: String) -> Bool {
        favoriteItems.contains { $0.id == itemId }
    }
    
    func toggleFavorite(item: MenuItem) {
        if isFavorite(itemId: item.id) {
            removeFromFavorites(itemId: item.id)
        } else {
            addToFavorites(item: item)
        }
    }
} 