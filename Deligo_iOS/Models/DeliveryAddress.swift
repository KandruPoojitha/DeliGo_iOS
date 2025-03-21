import Foundation
import CoreLocation

struct DeliveryAddress: Codable {
    var streetAddress: String
    var city: String
    var state: String
    var zipCode: String
    var unit: String?
    var instructions: String?
    var latitude: Double
    var longitude: Double
    var placeID: String
    
    private enum CodingKeys: String, CodingKey {
        case streetAddress
        case city
        case state
        case zipCode
        case unit
        case instructions
        case latitude
        case longitude
        case placeID
    }
    
    var formattedAddress: String {
        var components: [String] = [streetAddress]
        
        if let unit = unit {
            components.append("Unit \(unit)")
        }
        
        components.append("\(city), \(state) \(zipCode)")
        
        return components.joined(separator: ", ")
    }
    
    init(streetAddress: String, city: String, state: String, zipCode: String, unit: String? = nil, instructions: String? = nil, latitude: Double, longitude: Double, placeID: String) {
        self.streetAddress = streetAddress
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.unit = unit
        self.instructions = instructions
        self.latitude = latitude
        self.longitude = longitude
        self.placeID = placeID
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streetAddress = try container.decode(String.self, forKey: .streetAddress)
        city = try container.decode(String.self, forKey: .city)
        state = try container.decode(String.self, forKey: .state)
        zipCode = try container.decode(String.self, forKey: .zipCode)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        instructions = try container.decodeIfPresent(String.self, forKey: .instructions)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        placeID = try container.decode(String.self, forKey: .placeID)
    }
}

struct LocationSuggestion: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let placeID: String
    let coordinate: CLLocationCoordinate2D
} 
