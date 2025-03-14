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
    }
    
    func checkLocationAuthorization() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            DispatchQueue.global(qos: .userInitiated).async {
                self.locationManager.requestWhenInUseAuthorization()
            }
        case .restricted, .denied:
            DispatchQueue.main.async {
                self.locationError = "Location access denied. Please enable location services in Settings to see restaurant distances."
            }
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        @unknown default:
            DispatchQueue.main.async {
                self.locationError = "Unknown location authorization status"
            }
        }
    }
    
    func startUpdatingLocation() {
        if CLLocationManager.locationServicesEnabled() &&
           (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways) {
            locationManager.startUpdatingLocation()
            locationError = nil
        } else {
            locationError = "Location services are disabled. Please enable them in Settings to see restaurant distances."
        }
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            self.checkLocationAuthorization()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            guard let location = locations.last else { return }
            // Only update if accuracy is good enough
            if location.horizontalAccuracy <= 100 {
                self.location = location
                self.locationError = nil
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            print("Location manager failed with error: \(error.localizedDescription)")
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
