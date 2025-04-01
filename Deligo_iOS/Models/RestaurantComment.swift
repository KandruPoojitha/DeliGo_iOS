import Foundation

struct RestaurantComment: Identifiable {
    let id: String
    let userId: String
    let userName: String
    let comment: String
    let rating: Int
    let timestamp: TimeInterval
    
    var formattedDate: String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.userId = data["userId"] as? String ?? ""
        self.userName = data["userName"] as? String ?? "Anonymous"
        self.comment = data["comment"] as? String ?? ""
        self.rating = data["rating"] as? Int ?? 0
        self.timestamp = data["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970
    }
} 