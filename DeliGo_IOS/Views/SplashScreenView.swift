import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var opacity = 0.0
    
    var body: some View {
        if isActive {
            NavigationStack {
                LoginView()
            }
        } else {
            VStack {
                Image("deligo_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .opacity(opacity)
            .onAppear {
                // Fade in animation
                withAnimation(.easeIn(duration: 0.8)) {
                    self.opacity = 1.0
                }
                
                // Delay of 3 seconds before transitioning to LoginView
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeOut(duration: 0.3)) {
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