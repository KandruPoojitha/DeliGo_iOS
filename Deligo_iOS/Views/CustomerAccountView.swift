import SwiftUI

struct CustomerAccountView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            Text("Account")
                .navigationTitle("Account")
        }
    }
} 