import SwiftUI
import GoogleMaps
import CoreLocation

struct DriverOrderMapView: View {
    let order: DeliveryOrder
    @StateObject private var locationManager = LocationManager()
    @State private var camera = GMSCameraPosition.camera(withLatitude: 37.7749, longitude: -122.4194, zoom: 12)
    
    var body: some View {
        ZStack {
            GoogleMapView(camera: $camera, order: order, driverLocation: locationManager.location?.coordinate)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        // Driver Location Button
                        Button(action: {
                            if let location = locationManager.location?.coordinate {
                                camera = GMSCameraPosition.camera(withLatitude: location.latitude,
                                                               longitude: location.longitude,
                                                               zoom: 15)
                            }
                        }) {
                            HStack {
                                Image(systemName: "car.fill")
                                Text("Driver")
                            }
                            .padding(8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
                        // Restaurant Location Button
                        Button(action: {
                            if let restaurantLocation = order.restaurantLocation {
                                camera = GMSCameraPosition.camera(withLatitude: restaurantLocation.latitude,
                                                               longitude: restaurantLocation.longitude,
                                                               zoom: 15)
                            }
                        }) {
                            HStack {
                                Image(systemName: "fork.knife")
                                Text("Restaurant")
                            }
                            .padding(8)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
                        // Delivery Location Button
                        Button(action: {
                            if let deliveryLocation = order.deliveryLocation {
                                camera = GMSCameraPosition.camera(withLatitude: deliveryLocation.latitude,
                                                               longitude: deliveryLocation.longitude,
                                                               zoom: 15)
                            }
                        }) {
                            HStack {
                                Image(systemName: "house.fill")
                                Text("Delivery")
                            }
                            .padding(8)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            setupMap()
        }
    }
    
    private func setupMap() {
        // Calculate bounds that include locations based on order status
        let bounds: GMSCoordinateBounds
        
        if order.orderStatus == "driver_accepted" {
            // Only include driver and restaurant locations if order status is "driver_accepted"
            if let driverLoc = locationManager.location?.coordinate, let restaurantLoc = order.restaurantLocation {
                bounds = GMSCoordinateBounds(coordinate: driverLoc, coordinate: restaurantLoc)
            } else if let restaurantLoc = order.restaurantLocation {
                // Fallback if driver location isn't available
                bounds = GMSCoordinateBounds(coordinate: restaurantLoc, coordinate: restaurantLoc)
            } else if let driverLoc = locationManager.location?.coordinate {
                // Fallback if restaurant location isn't available
                bounds = GMSCoordinateBounds(coordinate: driverLoc, coordinate: driverLoc)
            } else {
                // Default to a standard location if no coordinates are available
                let defaultLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                bounds = GMSCoordinateBounds(coordinate: defaultLocation, coordinate: defaultLocation)
            }
        } else if order.orderStatus == "picked_up" {
            // Focus on driver and delivery location when order is picked up
            if let driverLoc = locationManager.location?.coordinate, let deliveryLoc = order.deliveryLocation {
                bounds = GMSCoordinateBounds(coordinate: driverLoc, coordinate: deliveryLoc)
            } else if let deliveryLoc = order.deliveryLocation {
                // Fallback if driver location isn't available
                bounds = GMSCoordinateBounds(coordinate: deliveryLoc, coordinate: deliveryLoc)
            } else if let driverLoc = locationManager.location?.coordinate {
                // Fallback if delivery location isn't available
                bounds = GMSCoordinateBounds(coordinate: driverLoc, coordinate: driverLoc)
            } else {
                // Default to a standard location if no coordinates are available
                let defaultLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                bounds = GMSCoordinateBounds(coordinate: defaultLocation, coordinate: defaultLocation)
            }
        } else {
            // Include all three locations for other order statuses
            let minLat = min(
                locationManager.location?.coordinate.latitude ?? 0,
                min(order.restaurantLocation?.latitude ?? 0, order.deliveryLocation?.latitude ?? 0)
            )
            let minLong = min(
                locationManager.location?.coordinate.longitude ?? 0,
                min(order.restaurantLocation?.longitude ?? 0, order.deliveryLocation?.longitude ?? 0)
            )
            let maxLat = max(
                locationManager.location?.coordinate.latitude ?? 0,
                max(order.restaurantLocation?.latitude ?? 0, order.deliveryLocation?.latitude ?? 0)
            )
            let maxLong = max(
                locationManager.location?.coordinate.longitude ?? 0,
                max(order.restaurantLocation?.longitude ?? 0, order.deliveryLocation?.longitude ?? 0)
            )
            
            bounds = GMSCoordinateBounds(
                coordinate: CLLocationCoordinate2D(latitude: minLat, longitude: minLong),
                coordinate: CLLocationCoordinate2D(latitude: maxLat, longitude: maxLong)
            )
        }
        
        // Calculate appropriate zoom level based on distance
        let span = max(
            abs(bounds.northEast.latitude - bounds.southWest.latitude),
            abs(bounds.northEast.longitude - bounds.southWest.longitude)
        )
        let zoom: Float = span > 0.1 ? 12 : 15
        
        // Calculate center point
        let centerLatitude = (bounds.northEast.latitude + bounds.southWest.latitude) / 2
        let centerLongitude = (bounds.northEast.longitude + bounds.southWest.longitude) / 2
        
        camera = GMSCameraPosition.camera(withLatitude: centerLatitude,
                                       longitude: centerLongitude,
                                       zoom: zoom)
    }
}

// Google Maps View using UIViewRepresentable
struct GoogleMapView: UIViewRepresentable {
    @Binding var camera: GMSCameraPosition
    let order: DeliveryOrder
    let driverLocation: CLLocationCoordinate2D?
    
    func makeUIView(context: Context) -> GMSMapView {
        let mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        mapView.settings.myLocationButton = true
        mapView.isMyLocationEnabled = true
        mapView.delegate = context.coordinator
        
        // Add markers
        addMarkers(to: mapView)
        
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.animate(to: camera)
        
        // Clear and re-add markers to ensure they're updated
        mapView.clear()
        addMarkers(to: mapView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func addMarkers(to mapView: GMSMapView) {
        // Add driver marker
        if let driverLocation = driverLocation {
            let driverMarker = GMSMarker(position: driverLocation)
            driverMarker.title = "Driver"
            driverMarker.icon = GMSMarker.markerImage(with: .blue)
            driverMarker.map = mapView
        }
        
        // Add restaurant marker if not in picked_up status
        if order.orderStatus != "picked_up" {
            if let restaurantLocation = order.restaurantLocation {
                let restaurantMarker = GMSMarker(position: restaurantLocation)
                restaurantMarker.title = "Restaurant"
                restaurantMarker.snippet = order.restaurantName
                restaurantMarker.icon = GMSMarker.markerImage(with: .orange)
                restaurantMarker.map = mapView
            }
        }
        
        // Only add delivery location marker if order status is NOT "driver_accepted"
        // Always show delivery marker when status is picked_up
        if order.orderStatus != "driver_accepted" || order.orderStatus == "picked_up" {
            if let deliveryLocation = order.deliveryLocation {
                let deliveryMarker = GMSMarker(position: deliveryLocation)
                deliveryMarker.title = "Delivery Location"
                deliveryMarker.snippet = order.address.streetAddress
                deliveryMarker.icon = GMSMarker.markerImage(with: .green)
                deliveryMarker.map = mapView
            }
        }
        
        // Draw path between points
        drawPath(on: mapView)
    }
    
    private func drawPath(on mapView: GMSMapView) {
        let path = GMSMutablePath()
        
        // Handle different path drawing based on order status
        if order.orderStatus == "driver_accepted" {
            // Path from driver to restaurant
            if let driverLocation = driverLocation, let restaurantLocation = order.restaurantLocation {
                path.add(driverLocation)
                path.add(restaurantLocation)
                
                // Create and style the polyline
                let polyline = GMSPolyline(path: path)
                polyline.strokeWidth = 3.0
                polyline.strokeColor = .systemBlue
                polyline.geodesic = true
                polyline.map = mapView
            }
        } else if order.orderStatus == "picked_up" {
            // Path from driver to delivery location
            if let driverLocation = driverLocation, let deliveryLocation = order.deliveryLocation {
                path.add(driverLocation)
                path.add(deliveryLocation)
                
                // Create and style the polyline
                let polyline = GMSPolyline(path: path)
                polyline.strokeWidth = 3.0
                polyline.strokeColor = .systemBlue
                polyline.geodesic = true
                polyline.map = mapView
            }
        } else {
            // Default path through all points
            if let driverLocation = driverLocation {
                path.add(driverLocation)
            }
            
            if let restaurantLocation = order.restaurantLocation {
                path.add(restaurantLocation)
                
                if let deliveryLocation = order.deliveryLocation {
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
    }
    
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapView
        
        init(_ parent: GoogleMapView) {
            self.parent = parent
        }
    }
}

// Location Manager to handle driver's location
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("Location access denied")
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
} 