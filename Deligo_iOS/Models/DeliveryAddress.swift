import Foundation
import CoreLocation

struct DeliveryAddress: Codable {
    var streetAddress: String
    var unit: String
    var instructions: String
    var latitude: Double?
    var longitude: Double?
    var placeID: String?
    
    var formattedAddress: String {
        var components = [streetAddress]
        if !unit.isEmpty {
            components.append("Unit \(unit)")
        }
        return components.joined(separator: ", ")
    }
}

struct LocationSuggestion: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let placeID: String
    let coordinate: CLLocationCoordinate2D
} 
