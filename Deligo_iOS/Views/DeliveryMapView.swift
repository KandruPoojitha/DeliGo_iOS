import SwiftUI
import GoogleMaps
import CoreLocation

struct DeliveryMapView: UIViewRepresentable {
    let driverLocation: CLLocationCoordinate2D?
    let restaurantLocation: CLLocationCoordinate2D
    let deliveryLocation: CLLocationCoordinate2D
    let restaurantName: String
    let deliveryAddress: String
    
    func makeUIView(context: Context) -> GMSMapView {
        // Create a map centered on the restaurant location initially
        let camera = GMSCameraPosition.camera(
            withLatitude: restaurantLocation.latitude,
            longitude: restaurantLocation.longitude,
            zoom: 13
        )
        
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.settings.myLocationButton = true
        mapView.settings.compassButton = true
        mapView.isMyLocationEnabled = true
        
        // Style the map
        do {
            if let styleURL = Bundle.main.url(forResource: "map_style", withExtension: "json") {
                mapView.mapStyle = try GMSMapStyle(contentsOfFileURL: styleURL)
            }
        } catch {
            print("Failed to load map style: \(error)")
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.clear()
        
        // Add driver marker (blue)
        if let driverLoc = driverLocation {
            let driverMarker = GMSMarker(position: driverLoc)
            driverMarker.title = "Driver Location"
            driverMarker.icon = GMSMarker.markerImage(with: .blue)
            driverMarker.map = mapView
        }
        
        // Add restaurant marker (red)
        let restaurantMarker = GMSMarker(position: restaurantLocation)
        restaurantMarker.title = restaurantName
        restaurantMarker.snippet = "Restaurant"
        restaurantMarker.icon = GMSMarker.markerImage(with: .red)
        restaurantMarker.map = mapView
        
        // Add delivery marker (green)
        let deliveryMarker = GMSMarker(position: deliveryLocation)
        deliveryMarker.title = "Delivery Location"
        deliveryMarker.snippet = deliveryAddress
        deliveryMarker.icon = GMSMarker.markerImage(with: .green)
        deliveryMarker.map = mapView
        
        // Create bounds that include all markers
        let bounds = GMSCoordinateBounds(coordinate: restaurantLocation, coordinate: deliveryLocation)
        if let driverLoc = driverLocation {
            bounds.includingCoordinate(driverLoc)
        }
        
        // Add some padding around the bounds
        let update = GMSCameraUpdate.fit(bounds, withPadding: 50.0)
        mapView.animate(with: update)
        
        // Draw route between points
        drawRoute(on: mapView)
    }
    
    private func drawRoute(on mapView: GMSMapView) {
        let path = GMSMutablePath()
        
        // Add driver location to path if available
        if let driverLoc = driverLocation {
            path.add(driverLoc)
        }
        
        // Add restaurant and delivery locations
        path.add(restaurantLocation)
        path.add(deliveryLocation)
        
        // Create and style the polyline
        let polyline = GMSPolyline(path: path)
        polyline.strokeWidth = 3.0
        polyline.strokeColor = .systemBlue
        polyline.geodesic = true
        polyline.map = mapView
    }
}

// Preview provider for SwiftUI canvas
struct DeliveryMapView_Previews: PreviewProvider {
    static var previews: some View {
        DeliveryMapView(
            driverLocation: CLLocationCoordinate2D(latitude: 45.5017, longitude: -73.5673),
            restaurantLocation: CLLocationCoordinate2D(latitude: 45.4972, longitude: -73.5708),
            deliveryLocation: CLLocationCoordinate2D(latitude: 45.5088, longitude: -73.5878),
            restaurantName: "Test Restaurant",
            deliveryAddress: "2275 Bd Saint-Joseph E, Montréal, QC H2H 1G4"
        )
        .frame(height: 300)
    }
} 