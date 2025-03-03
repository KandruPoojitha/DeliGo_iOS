import SwiftUI
import FirebaseCore

@main
struct Deligo_iOSApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            LoginView()
        }
    }
}
