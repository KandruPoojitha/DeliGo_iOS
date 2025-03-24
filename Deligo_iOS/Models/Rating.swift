import Foundation

struct Rating: Codable {
    let id: String
    let orderId: String
    let userId: String
    let restaurantId: String
    let rating: Int
    let comment: String?
    let createdAt: TimeInterval
    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.orderId = data["orderId"] as? String ?? ""
        self.userId = data["userId"] as? String ?? ""
        self.restaurantId = data["restaurantId"] as? String ?? ""
        self.rating = data["rating"] as? Int ?? 0
        self.comment = data["comment"] as? String
        self.createdAt = data["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
    }
    
    var toDictionary: [String: Any] {
        return [
            "orderId": orderId,
            "userId": userId,
            "restaurantId": restaurantId,
            "rating": rating,
            "comment": comment as Any,
            "createdAt": createdAt
        ]
    }
} 