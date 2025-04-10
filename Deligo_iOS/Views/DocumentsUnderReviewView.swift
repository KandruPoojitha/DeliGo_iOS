import SwiftUI

struct DocumentsUnderReviewView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            // Logout Button in top right
            HStack {
                Spacer()
                Button(action: {
                    authViewModel.logout()
                }) {
                    Text("Logout")
                        .foregroundColor(Color("F4A261"))
                }
                .padding()
            }
            
            Spacer()
            
            // Clock Icon
            Image(systemName: "clock.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(Color(hex: "F4A261"))
            
            // Title
            Text("Documents Under Review")
                .font(.title)
                .fontWeight(.bold)
            
            // Description
            Text("Your documents are being reviewed by our team. This process usually takes 1-2 business days.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
} 
