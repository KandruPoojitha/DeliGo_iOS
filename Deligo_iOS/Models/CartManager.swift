import Foundation
import FirebaseDatabase

class CartManager: ObservableObject {
    @Published var cartItems: [CartItem] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db: DatabaseReference
    private let userId: String
    private var cartRef: DatabaseReference
    
    init(userId: String) {
        self.userId = userId
        self.db = Database.database().reference()
        
        if userId.isEmpty {
            self.cartRef = self.db.child("temp_cart")
            print("CartManager initialized with empty userId. Using temporary reference.")
        } else {
            self.cartRef = self.db.child("customers").child(userId).child("cart")
            print("CartManager initialized with userId: \(userId)")
            loadCartItems()
        }
    }
    
    var totalCartPrice: Double {
        cartItems.reduce(0) { $0 + ($1.totalPrice * Double($1.quantity)) }
    }
    
    func validateRestaurants() -> Bool {
        guard !cartItems.isEmpty else { return true }
        let firstRestaurantId = cartItems[0].restaurantId
        return cartItems.allSatisfy { $0.restaurantId == firstRestaurantId }
    }
    
    func loadCartItems() {
        guard !userId.isEmpty else {
            error = "Invalid user ID"
            return
        }
        
        isLoading = true
        print("Loading cart items for user: \(userId)")
        
        let connectedRef = Database.database().reference(withPath: ".info/connected")
        connectedRef.observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            
            if let connected = snapshot.value as? Bool, !connected {
                self.error = "No internet connection. Some features may be limited."
                self.isLoading = false
                return
            }
            
            self.cartRef.observe(.value) { [weak self] snapshot in
                guard let self = self else { return }
                self.isLoading = false
                
                print("Firebase cart snapshot received. Has children: \(snapshot.hasChildren())")
                var items: [CartItem] = []
                
                for child in snapshot.children {
                    guard let snapshot = child as? DataSnapshot,
                          let dict = snapshot.value as? [String: Any] else {
                        print("Failed to parse snapshot: \(child)")
                        continue
                    }
                    
                    print("Processing cart item with ID: \(snapshot.key)")
                    let id = snapshot.key
                    let menuItemId = dict["menuItemId"] as? String ?? ""
                    let restaurantId = dict["restaurantId"] as? String ?? ""
                    let name = dict["name"] as? String ?? ""
                    let description = dict["description"] as? String ?? ""
                    let price = dict["price"] as? Double ?? 0.0
                    let imageURL = dict["imageURL"] as? String
                    
                    if let imageURL = imageURL, !imageURL.isEmpty {
                        print("Cart item has image URL: \(imageURL)")
                    } else {
                        print("Cart item has no valid image URL")
                    }
                    
                    let quantity = dict["quantity"] as? Int ?? 1
                    let specialInstructions = dict["specialInstructions"] as? String ?? ""
                    let totalPrice = dict["totalPrice"] as? Double ?? 0.0
                    
                    var customizations: [String: [CustomizationSelection]] = [:]
                    if let customizationsDict = dict["customizations"] as? [String: [[String: Any]]] {
                        for (optionId, selections) in customizationsDict {
                            customizations[optionId] = selections.compactMap { selectionDict in
                                guard let optionId = selectionDict["optionId"] as? String,
                                      let optionName = selectionDict["optionName"] as? String,
                                      let selectedItemsArray = selectionDict["selectedItems"] as? [[String: Any]] else {
                                    print("Failed to parse customization: \(selectionDict)")
                                    return nil
                                }
                                
                                let selectedItems = selectedItemsArray.compactMap { itemDict -> SelectedItem? in
                                    guard let id = itemDict["id"] as? String,
                                          let name = itemDict["name"] as? String,
                                          let price = itemDict["price"] as? Double else {
                                        print("Failed to parse selected item: \(itemDict)")
                                        return nil
                                    }
                                    return SelectedItem(id: id, name: name, price: price)
                                }
                                
                                return CustomizationSelection(
                                    optionId: optionId,
                                    optionName: optionName,
                                    selectedItems: selectedItems
                                )
                            }
                        }
                    }
                    
                    let cartItem = CartItem(
                        id: id,
                        menuItemId: menuItemId,
                        restaurantId: restaurantId,
                        name: name,
                        description: description,
                        price: price,
                        imageURL: imageURL,
                        quantity: quantity,
                        customizations: customizations,
                        specialInstructions: specialInstructions,
                        totalPrice: totalPrice
                    )
                    print("Successfully created cart item: \(name)")
                    items.append(cartItem)
                }
                
                DispatchQueue.main.async {
                    print("Updating cart items on main thread. Count: \(items.count)")
                    self.cartItems = items
                }
            }
        }
    }
    
    func addToCart(item: CartItem) {
        guard !userId.isEmpty else {
            error = "Invalid user ID"
            return
        }
        
        if !cartItems.isEmpty && cartItems[0].restaurantId != item.restaurantId {
            error = "Please complete or clear your current order before adding items from a different restaurant"
            return
        }
        
        isLoading = true
        print("Adding item to cart: \(item.name)")
        
        if let imageURL = item.imageURL {
            print("Item has image URL: \(imageURL)")
        } else {
            print("Item has no image URL")
        }
        
        let cartData: [String: Any] = [
            "menuItemId": item.menuItemId,
            "restaurantId": item.restaurantId,
            "name": item.name,
            "description": item.description,
            "price": item.price,
            "imageURL": item.imageURL ?? "",
            "quantity": item.quantity,
            "customizations": item.customizations.mapValues { selections in
                selections.map { selection in
                    [
                        "optionId": selection.optionId,
                        "optionName": selection.optionName,
                        "selectedItems": selection.selectedItems.map { item in
                            [
                                "id": item.id,
                                "name": item.name,
                                "price": item.price
                            ]
                        }
                    ]
                }
            },
            "specialInstructions": item.specialInstructions,
            "totalPrice": item.totalPrice,
            "timestamp": ServerValue.timestamp()
        ]
        
        cartRef.child(item.id).setValue(cartData) { [weak self] error, _ in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                print("Error adding item to cart: \(error.localizedDescription)")
                self.error = "Failed to add item to cart: \(error.localizedDescription)"
            } else {
                print("Successfully added item to cart: \(item.name)")
            }
        }
    }
    
    func removeFromCart(itemId: String) {
        guard !userId.isEmpty else {
            error = "Invalid user ID"
            return
        }
        
        isLoading = true
        cartRef.child(itemId).removeValue { [weak self] error, _ in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                print("Error removing item from cart: \(error.localizedDescription)")
                self.error = "Failed to remove item from cart: \(error.localizedDescription)"
            }
        }
    }
    
    func updateQuantity(itemId: String, quantity: Int) {
        guard !userId.isEmpty else {
            error = "Invalid user ID"
            return
        }
        
        isLoading = true
        cartRef.child(itemId).updateChildValues(["quantity": quantity]) { [weak self] error, _ in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                print("Error updating quantity: \(error.localizedDescription)")
                self.error = "Failed to update quantity: \(error.localizedDescription)"
            }
        }
    }
    
    func clearCart() {
        guard !userId.isEmpty else {
            error = "Invalid user ID"
            return
        }
        
        isLoading = true
        cartRef.removeValue { [weak self] error, _ in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                print("Error clearing cart: \(error.localizedDescription)")
                self.error = "Failed to clear cart: \(error.localizedDescription)"
            } else {
                DispatchQueue.main.async {
                    self.cartItems.removeAll()
                }
            }
        }
    }
} 