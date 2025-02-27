//
//  DeliGo_IOSApp.swift
//  DeliGo_IOS
//
//  Created by Prashanth Muppa on 2/27/25.
//

import SwiftUI
import FirebaseCore

@main
struct DeliGo_IOSApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
        }
    }
}
