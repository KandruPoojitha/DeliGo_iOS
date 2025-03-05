import SwiftUI
import FirebaseAuth

struct SplashScreenView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var isActive = false
    
    var body: some View {
        if isActive {
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
