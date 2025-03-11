import Foundation
import FirebaseDatabase

class CartManager: ObservableObject {
    @Published var cartItems: [CartItem] = []
    private let db = Database.database().reference()
    private let userId: String
    
    init(userId: String) {
        self.userId = userId
        print("CartManager initialized with userId: \(userId)")
        loadCartItems()
    }
    
    func loadCartItems() {
        print("Loading cart items for user: \(userId)")
        let cartRef = db.child("customers").child(userId).child("cart")
        print("Firebase path: \(cartRef.url)")
        
        cartRef.observe(.value) { [weak self] snapshot in
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
                let name = dict["name"] as? String ?? ""
                let description = dict["description"] as? String ?? ""
                let price = dict["price"] as? Double ?? 0.0
                let imageURL = dict["imageURL"] as? String
                let quantity = dict["quantity"] as? Int ?? 1
                let specialInstructions = dict["specialInstructions"] as? String ?? ""
                let totalPrice = dict["totalPrice"] as? Double ?? 0.0
                
                // Parse customizations
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
                self?.cartItems = items
            }
        }
    }
    
    func addToCart(item: CartItem) {
        print("Adding item to cart: \(item.name)")
        let cartRef = db.child("customers").child(userId).child("cart").child(item.id)
        
        let cartData: [String: Any] = [
            "menuItemId": item.menuItemId,
            "name": item.name,
            "description": item.description,
            "price": item.price,
            "imageURL": item.imageURL as Any,
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
        
        cartRef.setValue(cartData) { error, _ in
            if let error = error {
                print("Error adding item to cart: \(error.localizedDescription)")
            } else {
                print("Successfully added item to cart: \(item.name)")
            }
        }
    }
    
    func removeFromCart(itemId: String) {
        db.child("customers").child(userId).child("cart").child(itemId).removeValue()
    }
    
    func updateQuantity(itemId: String, quantity: Int) {
        db.child("customers").child(userId).child("cart").child(itemId).updateChildValues([
            "quantity": quantity
        ])
    }
    
    func clearCart() {
        db.child("customers").child(userId).child("cart").removeValue()
    }
    
    var totalCartPrice: Double {
        cartItems.reduce(0) { $0 + $1.totalPrice }
    }
} 