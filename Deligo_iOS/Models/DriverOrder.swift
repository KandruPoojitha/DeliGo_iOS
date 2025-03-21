import Foundation
import FirebaseDatabase

struct DriverOrder: Identifiable {
    let id: String
    let createdAt: TimeInterval
    let deliveryFee: Double
    let deliveryOption: String
    let items: [DriverOrderItem]
    let latitude: Double
    let longitude: Double
    let orderStatus: String
    let paymentMethod: String
    let restaurantId: String
    let restaurantName: String
    let restaurantAddress: String
    let deliveryAddress: String
    let status: String
    let subtotal: Double
    let tipAmount: Double
    let tipPercentage: Double
    let total: Double
    let updatedAt: TimeInterval
    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.createdAt = data["createdAt"] as? TimeInterval ?? 0
        self.deliveryFee = data["deliveryFee"] as? Double ?? 0.0
        self.deliveryOption = data["deliveryOption"] as? String ?? "Delivery"
        self.latitude = data["latitude"] as? Double ?? 0.0
        self.longitude = data["longitude"] as? Double ?? 0.0
        self.orderStatus = data["order_status"] as? String ?? "pending"
        self.paymentMethod = data["paymentMethod"] as? String ?? ""
        self.restaurantId = data["restaurantId"] as? String ?? ""
        self.restaurantName = data["restaurantName"] as? String ?? "Restaurant Name"
        self.restaurantAddress = data["restaurantAddress"] as? String ?? ""
        self.deliveryAddress = data["deliveryAddress"] as? String ?? ""
        self.status = data["status"] as? String ?? "pending"
        self.subtotal = data["subtotal"] as? Double ?? 0.0
        self.tipAmount = data["tipAmount"] as? Double ?? 0.0
        self.tipPercentage = data["tipPercentage"] as? Double ?? 0.0
        self.total = data["total"] as? Double ?? 0.0
        self.updatedAt = data["updatedAt"] as? TimeInterval ?? 0
        
        // Parse items
        if let itemsData = data["items"] as? [[String: Any]] {
            self.items = itemsData.map { itemData in
                DriverOrderItem(
                    id: itemData["id"] as? String ?? UUID().uuidString,
                    name: itemData["name"] as? String ?? "",
                    price: itemData["price"] as? Double ?? 0.0,
                    quantity: itemData["quantity"] as? Int ?? 1,
                    specialInstructions: itemData["specialInstructions"] as? String ?? ""
                )
            }
        } else {
            self.items = []
        }
    }
    
    var orderStatusDisplay: String {
        switch orderStatus.lowercased() {
        case "pending": return "Pending"
        case "accepted": return "Accepted"
        case "preparing": return "Preparing"
        case "ready": return "Ready for Pickup"
        case "picked_up": return "Picked Up"
        case "delivering": return "Delivering"
        case "delivered": return "Delivered"
        case "cancelled": return "Cancelled"
        default: return orderStatus.capitalized
        }
    }
    
    var statusColor: String {
        switch orderStatus.lowercased() {
        case "pending": return "FFA500" // Orange
        case "accepted": return "2196F3" // Blue
        case "preparing": return "FF9800" // Dark Orange
        case "ready": return "9C27B0" // Purple
        case "picked_up": return "9C27B0" // Purple
        case "delivering": return "4CAF50" // Green
        case "delivered": return "8BC34A" // Light Green
        case "cancelled": return "F44336" // Red
        default: return "9E9E9E" // Grey
        }
    }
}

// Renamed to avoid conflict with other OrderItem definitions
struct DriverOrderItem: Identifiable {
    let id: String
    let name: String
    let price: Double
    let quantity: Int
    let specialInstructions: String
    
    var totalPrice: Double {
        price * Double(quantity)
    }
}

enum OrderStatus: String {
    case pending = "pending"
    case accepted = "accepted"
    case pickedUp = "picked_up"
    case delivering = "delivering"
    case delivered = "delivered"
    case cancelled = "cancelled"
    
    var displayText: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .pickedUp: return "Picked Up"
        case .delivering: return "Delivering"
        case .delivered: return "Delivered"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "FFA500" // Orange
        case .accepted: return "2196F3" // Blue
        case .pickedUp: return "9C27B0" // Purple
        case .delivering: return "4CAF50" // Green
        case .delivered: return "8BC34A" // Light Green
        case .cancelled: return "F44336" // Red
        }
    }
} 