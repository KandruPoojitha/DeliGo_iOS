import Foundation
import FirebaseDatabase

class AdminOrderManagementViewModel: ObservableObject {
    @Published var orders: [AdminOrder] = []
    @Published var isLoading = false
    private let database = Database.database().reference()
    
    struct OrderItem: Identifiable {
        let id: String
        let name: String
        let quantity: Int
        let price: Double
        let specialInstructions: String?
        let customizations: [String: Any]?
        
        var formattedCustomizations: [String] {
            guard let customizations = customizations else { return [] }
            var result: [String] = []
            
            for (key, value) in customizations {
                if let dict = value as? [String: Any] {
                    // Handle dictionary values
                    let selectedItems = dict.compactMap { (itemKey, itemValue) -> String? in
                        if let isSelected = itemValue as? Bool, isSelected {
                            return itemKey
                        } else if let stringValue = itemValue as? String {
                            return "\(itemKey): \(stringValue)"
                        }
                        return nil
                    }
                    if !selectedItems.isEmpty {
                        result.append("\(key): \(selectedItems.joined(separator: ", "))")
                    }
                } else if let stringValue = value as? String {
                    // Handle string values
                    result.append("\(key): \(stringValue)")
                } else if let boolValue = value as? Bool {
                    // Handle boolean values
                    if boolValue {
                        result.append(key)
                    }
                } else if let arrayValue = value as? [String] {
                    // Handle array values
                    result.append("\(key): \(arrayValue.joined(separator: ", "))")
                }
            }
            
            return result
        }
    }
    
    struct AdminOrder: Identifiable {
        let id: String
        let orderStatus: String
        let restaurantId: String
        let restaurantName: String
        let customerName: String
        let driverName: String?
        let total: Double
        let createdAt: TimeInterval
        let items: [OrderItem]
        
        var formattedDate: String {
            let date = Date(timeIntervalSince1970: createdAt)
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        
        // Helper to determine if order is active (not delivered)
        var isActive: Bool {
            return orderStatus.lowercased() != "delivered"
        }
    }
    
    func loadOrders() {
        isLoading = true
        orders.removeAll()
        
        database.child("orders").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            self.orders.removeAll()
            var tempOrders: [AdminOrder] = []
            let group = DispatchGroup()
            
            for child in snapshot.children {
                guard let snapshot = child as? DataSnapshot,
                      let orderData = snapshot.value as? [String: Any] else { continue }
                
                let orderId = snapshot.key
                let orderStatus = orderData["order_status"] as? String ?? "unknown"
                let restaurantId = orderData["restaurantId"] as? String ?? ""
                let customerName = orderData["customerName"] as? String ?? "Unknown Customer"
                let driverName = orderData["driverName"] as? String
                let total = orderData["total"] as? Double ?? 0.0
                let createdAt = orderData["createdAt"] as? TimeInterval ?? 0
                
                // Parse order items
                var orderItems: [OrderItem] = []
                if let itemsData = orderData["items"] as? [[String: Any]] {
                    for (index, item) in itemsData.enumerated() {
                        let itemId = item["id"] as? String ?? "\(index)"
                        let name = item["name"] as? String ?? "Unknown Item"
                        let quantity = item["quantity"] as? Int ?? 1
                        let price = item["price"] as? Double ?? 0.0
                        let specialInstructions = item["specialInstructions"] as? String
                        let customizations = item["customizations"] as? [String: Any]
                        
                        orderItems.append(OrderItem(
                            id: itemId,
                            name: name,
                            quantity: quantity,
                            price: price,
                            specialInstructions: specialInstructions,
                            customizations: customizations
                        ))
                    }
                }
                
                // Fetch restaurant name from store_info
                group.enter()
                self.database.child("restaurants").child(restaurantId).child("store_info").child("name").observeSingleEvent(of: .value) { snapshot in
                    let restaurantName = snapshot.value as? String ?? "Unknown Restaurant"
                    
                    let order = AdminOrder(
                        id: orderId,
                        orderStatus: orderStatus,
                        restaurantId: restaurantId,
                        restaurantName: restaurantName,
                        customerName: customerName,
                        driverName: driverName,
                        total: total,
                        createdAt: createdAt,
                        items: orderItems
                    )
                    
                    tempOrders.append(order)
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                // Sort orders: active orders first (by date), then delivered orders (by date)
                self.orders = tempOrders.sorted { order1, order2 in
                    if order1.isActive == order2.isActive {
                        return order1.createdAt > order2.createdAt
                    }
                    return order1.isActive && !order2.isActive
                }
                self.isLoading = false
            }
        }
    }
    
    func statusColor(for status: String) -> String {
        switch status.lowercased() {
        case "pending": return "FFA500" // Orange
        case "accepted": return "2196F3" // Blue
        case "preparing": return "FF9800" // Dark Orange
        case "ready_for_pickup": return "9C27B0" // Purple
        case "picked_up": return "4CAF50" // Green
        case "delivered": return "8BC34A" // Light Green
        case "cancelled", "rejected": return "F44336" // Red
        default: return "9E9E9E" // Grey
        }
    }
} 