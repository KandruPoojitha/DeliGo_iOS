import CoreLocation
import SwiftUI

class CustomLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    private var lastLocationUpdate: Date?
    private var isUpdatingLocation = false
    
    override init() {
        authorizationStatus = locationManager.authorizationStatus
        
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone  // Update on any movement
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = false
        
        #if targetEnvironment(simulator)
        print("DEBUG: Running in simulator")
        locationManager.distanceFilter = 1  // Update more frequently in simulator
        #endif
        
        print("""
            DEBUG: CustomLocationManager initialized:
            - Authorization status: \(locationManager.authorizationStatus.rawValue)
            """)
    }
    
    func requestLocationPermission() {
        print("DEBUG: Requesting location permission")
        DispatchQueue.global().async {
            if CLLocationManager.locationServicesEnabled() {
                DispatchQueue.main.async {
                    self.locationManager.requestWhenInUseAuthorization()
                }
            } else {
                print("DEBUG: Location services are disabled system-wide")
            }
        }
    }
    
    private func handleAuthorizationStatus(_ status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                print("DEBUG: Location authorization granted")
                self.startUpdatingLocation()
            case .denied:
                print("DEBUG: Location authorization denied by user")
                self.stopUpdatingLocation()
            case .restricted:
                print("DEBUG: Location authorization restricted")
                self.stopUpdatingLocation()
            case .notDetermined:
                print("DEBUG: Location authorization not determined")
                self.requestLocationPermission()
            @unknown default:
                print("DEBUG: Unknown location authorization status")
                self.stopUpdatingLocation()
            }
        }
    }
    
    func startUpdatingLocation() {
        guard !isUpdatingLocation else { return }
        
        DispatchQueue.global().async {
            if CLLocationManager.locationServicesEnabled() {
                DispatchQueue.main.async {
                    self.locationManager.startUpdatingLocation()
                    self.isUpdatingLocation = true
                    print("DEBUG: Started location updates")
                }
            } else {
                print("DEBUG: Cannot start updates - Location services disabled")
            }
        }
    }
    
    func stopUpdatingLocation() {
        guard isUpdatingLocation else { return }
        
        DispatchQueue.main.async {
            self.locationManager.stopUpdatingLocation()
            self.isUpdatingLocation = false
            print("DEBUG: Stopped location updates")
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("DEBUG: Location authorization status changed to: \(manager.authorizationStatus.rawValue)")
        handleAuthorizationStatus(manager.authorizationStatus)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("""
            DEBUG: Location update received:
            - Number of locations: \(locations.count)
            - Locations: \(locations.map { "(\($0.coordinate.latitude), \($0.coordinate.longitude))" }.joined(separator: ", "))
            """)
        
        guard let location = locations.last else {
            print("DEBUG: No location data received")
            return
        }
        
        // Filter out invalid locations
        if location.horizontalAccuracy < 0 || location.horizontalAccuracy > 100 {
            print("DEBUG: Skipping inaccurate location update: accuracy \(location.horizontalAccuracy)m")
            return
        }
        
        // Check if the location is recent (within last 60 seconds)
        let locationAge = -location.timestamp.timeIntervalSinceNow
        if locationAge > 60 {
            print("DEBUG: Skipping old location update: age \(locationAge)s")
            return
        }
        
        // Validate coordinates
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        guard latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180 else {
            print("DEBUG: Invalid coordinates received: (\(latitude), \(longitude))")
            return
        }
        
        print("""
            DEBUG: Valid location update:
            - Coordinates: (\(latitude), \(longitude))
            - Accuracy: \(location.horizontalAccuracy)m
            - Speed: \(location.speed)m/s
            - Course: \(location.course)°
            - Age: \(locationAge)s
            - Timestamp: \(location.timestamp)
            """)
        
        DispatchQueue.main.async {
            print("DEBUG: Publishing new location to observers")
            self.location = location
            self.lastLocationUpdate = Date()
            print("DEBUG: Location published successfully")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("DEBUG: Location manager failed with error: \(error.localizedDescription)")
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                print("DEBUG: Location access denied by user")
                DispatchQueue.main.async {
                    self.stopUpdatingLocation()
                }
            case .locationUnknown:
                print("DEBUG: Location currently unavailable")
            case .network:
                print("DEBUG: Network error occurred")
            case .headingFailure:
                print("DEBUG: Heading not available")
            case .rangingUnavailable:
                print("DEBUG: Ranging unavailable")
            case .rangingFailure:
                print("DEBUG: Ranging failure")
            default:
                print("DEBUG: Other location error: \(clError.code)")
            }
        }
    }
} 