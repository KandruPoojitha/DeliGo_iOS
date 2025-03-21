import SwiftUI
import FirebaseAuth

struct SplashScreenView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var isActive = false
    @State private var forceLogout = false
    
    var body: some View {
        if forceLogout {
            LoginView()
        } else if isActive {
            if authViewModel.isAuthenticated {
                HomeView(authViewModel: authViewModel)
            } else {
                LoginView()
            }
        } else {
            VStack {
                Image("deligo_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            }
            .onAppear {
                // Set up notification for logout
                NotificationCenter.default.addObserver(
                    forName: Notification.Name("UserDidLogout"),
                    object: nil,
                    queue: .main
                ) { _ in
                    print("DEBUG: SplashScreenView received logout notification")
                    forceLogout = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashScreenView()
} 
