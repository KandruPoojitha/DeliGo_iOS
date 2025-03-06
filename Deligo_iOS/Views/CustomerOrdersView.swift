import SwiftUI

struct CustomerOrdersView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            Text("Orders")
                .navigationTitle("Orders")
        }
    }
} 