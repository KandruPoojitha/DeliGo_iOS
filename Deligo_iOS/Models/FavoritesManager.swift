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
                
                let item = MenuItem(
                    id: id,
                    name: name,
                    description: description,
                    price: price,
                    imageURL: imageURL,
                    category: category,
                    isAvailable: true,
                    customizationOptions: [] // We'll load these when needed
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
        let favoriteData: [String: Any] = [
            "id": item.id,
            "name": item.name,
            "description": item.description,
            "price": item.price,
            "imageURL": item.imageURL as Any,
            "category": item.category,
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