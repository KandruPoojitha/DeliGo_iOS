import SwiftUI
import FirebaseCore
import GoogleMaps
import GooglePlaces

@main
struct Deligo_iOSApp: App {
    init() {
        FirebaseApp.configure()
        
        // Initialize Google Maps and Places SDK
        if let path = Bundle.main.path(forResource: "GoogleMapsConfig", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let apiKey = dict["GOOGLE_MAPS_API_KEY"] as? String {
            GMSServices.provideAPIKey(apiKey)
            GMSPlacesClient.provideAPIKey(apiKey)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
        }
    }
}
