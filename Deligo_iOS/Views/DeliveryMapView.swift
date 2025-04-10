import SwiftUI
import GoogleMaps
import CoreLocation

struct DeliveryMapView: UIViewRepresentable {
    let driverLocation: CLLocationCoordinate2D?
    let restaurantLocation: CLLocationCoordinate2D
    let deliveryLocation: CLLocationCoordinate2D
    let restaurantName: String
    let deliveryAddress: String
    var orderStatus: String = "" // Added parameter to track order status
    
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
        
        // Add restaurant marker (red) if status is NOT picked_up
        if orderStatus != "picked_up" {
            let restaurantMarker = GMSMarker(position: restaurantLocation)
            restaurantMarker.title = restaurantName
            restaurantMarker.snippet = "Restaurant"
            restaurantMarker.icon = GMSMarker.markerImage(with: .red)
            restaurantMarker.map = mapView
        }
        
        // Only add delivery location marker if order status is NOT driver_accepted
        // Always show delivery marker when status is picked_up
        if orderStatus != "driver_accepted" || orderStatus == "picked_up" {
            let deliveryMarker = GMSMarker(position: deliveryLocation)
            deliveryMarker.title = "Delivery Location"
            deliveryMarker.snippet = deliveryAddress
            deliveryMarker.icon = GMSMarker.markerImage(with: .green)
            deliveryMarker.map = mapView
        }
        
        // Create bounds based on order status
        var bounds: GMSCoordinateBounds
        
        if orderStatus == "driver_accepted" {
            // Only include driver and restaurant
            if let driverLoc = driverLocation {
                bounds = GMSCoordinateBounds(coordinate: driverLoc, coordinate: restaurantLocation)
            } else {
                // Fallback if driver location is not available
                bounds = GMSCoordinateBounds(coordinate: restaurantLocation, coordinate: restaurantLocation)
            }
        } else if orderStatus == "picked_up" {
            // Focus on driver and delivery location
            if let driverLoc = driverLocation {
                bounds = GMSCoordinateBounds(coordinate: driverLoc, coordinate: deliveryLocation)
            } else {
                // Fallback if driver location is not available
                bounds = GMSCoordinateBounds(coordinate: deliveryLocation, coordinate: deliveryLocation)
            }
        } else {
            // Include all three points
            bounds = GMSCoordinateBounds(coordinate: restaurantLocation, coordinate: deliveryLocation)
            if let driverLoc = driverLocation {
                bounds = bounds.includingCoordinate(driverLoc)
            }
        }
        
        // Add some padding around the bounds
        let update = GMSCameraUpdate.fit(bounds, withPadding: 50.0)
        mapView.animate(with: update)
        
        // Draw route between points
        drawRoute(on: mapView)
    }
    
    private func drawRoute(on mapView: GMSMapView) {
        let path = GMSMutablePath()
        
        // Handle different path drawing based on order status
        if orderStatus == "driver_accepted" {
            // Path from driver to restaurant
            if let driverLoc = driverLocation {
                path.add(driverLoc)
                path.add(restaurantLocation)
            }
        } else if orderStatus == "picked_up" {
            // Path from driver to delivery location
            if let driverLoc = driverLocation {
                path.add(driverLoc)
                path.add(deliveryLocation)
            }
        } else {
            // Default path through all points
            if let driverLoc = driverLocation {
                path.add(driverLoc)
            }
            path.add(restaurantLocation)
            path.add(deliveryLocation)
        }
        
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