import Foundation

struct CartItem: Identifiable, Equatable, Codable {
    let id: String
    let menuItemId: String
    let restaurantId: String
    let name: String
    let description: String
    let price: Double
    let imageURL: String?
    let quantity: Int
    let customizations: [String: [CustomizationSelection]]
    let specialInstructions: String
    let totalPrice: Double
    
    private enum CodingKeys: String, CodingKey {
        case id
        case menuItemId
        case restaurantId
        case name
        case description
        case price
        case imageURL
        case quantity
        case customizations
        case specialInstructions
        case totalPrice
    }
    
    static func == (lhs: CartItem, rhs: CartItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.menuItemId == rhs.menuItemId &&
        lhs.restaurantId == rhs.restaurantId &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.price == rhs.price &&
        lhs.imageURL == rhs.imageURL &&
        lhs.quantity == rhs.quantity &&
        lhs.totalPrice == rhs.totalPrice &&
        lhs.specialInstructions == rhs.specialInstructions &&
        NSDictionary(dictionary: lhs.customizations) == NSDictionary(dictionary: rhs.customizations)
    }
}

struct CustomizationSelection: Codable, Equatable {
    let optionId: String
    let optionName: String
    let selectedItems: [SelectedItem]
}

struct SelectedItem: Codable, Equatable {
    let id: String
    let name: String
    let price: Double
} 