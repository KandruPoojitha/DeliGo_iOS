import CoreLocation
import SwiftUI

class CustomLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var locationError: String?
    
    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        print("DEBUG: CustomLocationManager initialized with auth status: \(authorizationStatus.rawValue)")
    }
    
    func checkLocationAuthorization() {
        print("DEBUG: Checking location authorization")
        switch locationManager.authorizationStatus {
        case .notDetermined:
            print("DEBUG: Location authorization not determined, requesting permission")
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            print("DEBUG: Location access denied or restricted")
            DispatchQueue.main.async {
                self.locationError = "Location access denied. Please enable location services in Settings to see restaurant distances."
            }
        case .authorizedWhenInUse, .authorizedAlways:
            print("DEBUG: Location access authorized, starting updates")
            startUpdatingLocation()
        @unknown default:
            print("DEBUG: Unknown location authorization status")
            DispatchQueue.main.async {
                self.locationError = "Unknown location authorization status"
            }
        }
    }
    
    func startUpdatingLocation() {
        print("DEBUG: Starting location updates")
        if CLLocationManager.locationServicesEnabled() &&
           (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways) {
            locationManager.startUpdatingLocation()
            // Force an immediate location update request
            locationManager.requestLocation()
            locationError = nil
            print("DEBUG: Location updates started")
        } else {
            print("DEBUG: Location services disabled")
            locationError = "Location services are disabled. Please enable them in Settings to see restaurant distances."
        }
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("DEBUG: Location authorization changed to: \(manager.authorizationStatus.rawValue)")
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            self.checkLocationAuthorization()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            guard let location = locations.last else { return }
            print("DEBUG: Received location update with accuracy: \(location.horizontalAccuracy)")
            
            // Accept any location update with reasonable accuracy
            if location.horizontalAccuracy <= 1000 {
                print("DEBUG: Location updated to: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                self.location = location
                self.locationError = nil
                
                // Notify that we've received a location
                NotificationCenter.default.post(name: NSNotification.Name("LocationUpdated"), object: nil)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("DEBUG: Location manager failed with error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = "Location access denied. Please enable location services in Settings."
                case .locationUnknown:
                    self.locationError = "Unable to determine location. Please try again."
                default:
                    self.locationError = "Error getting location: \(error.localizedDescription)"
                }
            } else {
                self.locationError = "Error getting location: \(error.localizedDescription)"
            }
        }
    }
} 
