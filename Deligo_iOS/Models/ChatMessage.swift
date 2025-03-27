import Foundation
import FirebaseDatabase

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let senderId: String
    let senderName: String
    let senderType: String // "customer" or "restaurant"
    let message: String
    let timestamp: TimeInterval
    let isRead: Bool
    
    enum SenderType: String {
        case customer
        case restaurant
        case driver
        case admin
    }
    
    var formattedTime: String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var formattedDate: String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.senderId = data["senderId"] as? String ?? ""
        self.senderName = data["senderName"] as? String ?? "Unknown"
        self.senderType = data["senderType"] as? String ?? "customer"
        self.message = data["message"] as? String ?? ""
        self.timestamp = data["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970
        self.isRead = data["isRead"] as? Bool ?? false
    }
    
    func toDict() -> [String: Any] {
        return [
            "senderId": senderId,
            "senderName": senderName,
            "senderType": senderType,
            "message": message,
            "timestamp": timestamp,
            "isRead": isRead
        ]
    }
    
    static func fromDict(_ dict: [String: Any], id: String) -> ChatMessage? {
        guard let senderId = dict["senderId"] as? String,
              let senderName = dict["senderName"] as? String,
              let senderType = dict["senderType"] as? String,
              let message = dict["message"] as? String,
              let timestamp = dict["timestamp"] as? TimeInterval else {
            return nil
        }
        
        let isRead = dict["isRead"] as? Bool ?? false
        
        return ChatMessage(
            id: id,
            data: [
                "senderId": senderId,
                "senderName": senderName,
                "senderType": senderType,
                "message": message,
                "timestamp": timestamp,
                "isRead": isRead
            ]
        )
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id &&
               lhs.senderId == rhs.senderId &&
               lhs.senderName == rhs.senderName &&
               lhs.senderType == rhs.senderType &&
               lhs.message == rhs.message &&
               lhs.timestamp == rhs.timestamp &&
               lhs.isRead == rhs.isRead
    }
}

struct ChatThread: Identifiable, Equatable {
    var id: String
    var customerId: String
    var customerName: String
    var lastMessage: String
    var lastMessageTimestamp: Double
    var unreadCount: Int
    var userRole: String = "Customer" // Default to Customer
    
    static func fromDict(_ dict: [String: Any], id: String) -> ChatThread? {
        guard let customerId = dict["customerId"] as? String,
              let customerName = dict["customerName"] as? String,
              let lastMessage = dict["lastMessage"] as? String,
              let lastMessageTimestamp = dict["lastMessageTimestamp"] as? Double,
              let unreadCount = dict["unreadCount"] as? Int else {
            return nil
        }
        
        var thread = ChatThread(
            id: id,
            customerId: customerId,
            customerName: customerName,
            lastMessage: lastMessage,
            lastMessageTimestamp: lastMessageTimestamp,
            unreadCount: unreadCount
        )
        
        // If userRole is available in the data, use it
        if let userRole = dict["userRole"] as? String {
            thread.userRole = userRole
        }
        
        return thread
    }
    
    static func == (lhs: ChatThread, rhs: ChatThread) -> Bool {
        return lhs.id == rhs.id &&
               lhs.customerId == rhs.customerId &&
               lhs.customerName == rhs.customerName &&
               lhs.lastMessage == rhs.lastMessage &&
               lhs.lastMessageTimestamp == rhs.lastMessageTimestamp &&
               lhs.unreadCount == rhs.unreadCount &&
               lhs.userRole == rhs.userRole
    }
} 
