import SwiftUI
import FirebaseAuth

struct SplashScreenView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isActive = false
    @State private var forceLogout = false
    
    var body: some View {
        if forceLogout {
            LoginView()
                .environmentObject(authViewModel)
                .alert(isPresented: .constant(authViewModel.errorMessage != nil)) {
                    Alert(
                        title: Text("Account Blocked"),
                        message: Text(authViewModel.errorMessage ?? ""),
                        dismissButton: .default(Text("OK")) {
                            authViewModel.errorMessage = nil
                        }
                    )
                }
        } else if isActive {
            if authViewModel.isAuthenticated {
                HomeView(authViewModel: authViewModel)
            } else {
                LoginView()
                    .environmentObject(authViewModel)
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
                    // Check and load user data if someone is already logged in
                    if Auth.auth().currentUser != nil {
                        authViewModel.loadUserProfile()
                    }
                    
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
        .environmentObject(AuthViewModel())
} 
