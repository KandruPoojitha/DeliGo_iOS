import Foundation
import FirebaseDatabase

struct ChatMessage: Identifiable, Codable, Equatable {
    var id: String
    var senderId: String
    var senderName: String
    var senderType: SenderType
    var message: String
    var timestamp: Double
    var isRead: Bool
    
    enum SenderType: String, Codable {
        case customer
        case admin
    }
    
    var formattedDate: String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    static func fromDict(_ dict: [String: Any], id: String) -> ChatMessage? {
        guard let senderId = dict["senderId"] as? String,
              let senderName = dict["senderName"] as? String,
              let senderTypeRaw = dict["senderType"] as? String,
              let message = dict["message"] as? String,
              let timestamp = dict["timestamp"] as? Double,
              let isRead = dict["isRead"] as? Bool else {
            return nil
        }
        
        let senderType = SenderType(rawValue: senderTypeRaw) ?? .customer
        
        return ChatMessage(
            id: id,
            senderId: senderId,
            senderName: senderName,
            senderType: senderType,
            message: message,
            timestamp: timestamp,
            isRead: isRead
        )
    }
    
    func toDict() -> [String: Any] {
        return [
            "senderId": senderId,
            "senderName": senderName,
            "senderType": senderType.rawValue,
            "message": message,
            "timestamp": timestamp,
            "isRead": isRead
        ]
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
