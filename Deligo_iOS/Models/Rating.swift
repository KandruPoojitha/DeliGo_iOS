import Foundation

enum RatingType: String, Codable {
    case restaurant
    case driver
}

struct Rating: Codable {
    let id: String
    let orderId: String
    let userId: String
    let targetId: String // Can be restaurantId or driverId
    let ratingType: RatingType
    let rating: Int
    let comment: String?
    let createdAt: TimeInterval
    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.orderId = data["orderId"] as? String ?? ""
        self.userId = data["userId"] as? String ?? ""
        self.targetId = data["targetId"] as? String ?? ""
        self.ratingType = RatingType(rawValue: data["ratingType"] as? String ?? "restaurant") ?? .restaurant
        self.rating = data["rating"] as? Int ?? 0
        self.comment = data["comment"] as? String
        self.createdAt = data["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
    }
    
    var toDictionary: [String: Any] {
        return [
            "orderId": orderId,
            "userId": userId,
            "targetId": targetId,
            "ratingType": ratingType.rawValue,
            "rating": rating,
            "comment": comment as Any,
            "createdAt": createdAt
        ]
    }
} 