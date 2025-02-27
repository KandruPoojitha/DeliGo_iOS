import SwiftUI

struct HomeView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            switch authViewModel.currentUserRole {
            case .customer:
                CustomerHomeView()
            case .restaurant:
                RestaurantHomeView()
            case .driver:
                DriverHomeView()
            case .none:
                // Show error or return to login
                Text("No role assigned")
                    .onAppear {
                        authViewModel.logout()
                    }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    authViewModel.logout()
                }) {
                    Text("Logout")
                        .foregroundColor(Color(hex: "F4A261"))
                }
            }
        }
    }
}

struct CustomerHomeView: View {
    var body: some View {
        VStack {
            Text("Welcome Customer")
                .font(.title)
                .padding()
            
            // Add your customer-specific UI here
        }
    }
}

struct RestaurantHomeView: View {
    var body: some View {
        VStack {
            Text("Welcome Restaurant")
                .font(.title)
                .padding()
            
            // Add your restaurant-specific UI here
        }
    }
}

struct DriverHomeView: View {
    var body: some View {
        VStack {
            Text("Welcome Driver")
                .font(.title)
                .padding()
            
            // Add your driver-specific UI here
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
} 