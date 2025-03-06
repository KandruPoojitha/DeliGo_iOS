import SwiftUI

struct CartView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            Text("Cart")
                .navigationTitle("Cart")
        }
    }
} 