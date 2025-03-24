import SwiftUI
import FirebaseDatabase

struct RateOrderView: View {
    let order: CustomerOrder
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int = 5
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let database = Database.database().reference()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Rate your order")) {
                    HStack {
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: index <= rating ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .onTapGesture {
                                    rating = index
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Comments (Optional)")) {
                    TextEditor(text: $comment)
                        .frame(height: 100)
                }
                
                Section {
                    Button(action: submitRating) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Submit Rating")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .navigationTitle("Rate Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func submitRating() {
        isSubmitting = true
        
        let ratingData: [String: Any] = [
            "orderId": order.id,
            "userId": order.userId,
            "restaurantId": order.restaurantId,
            "rating": rating,
            "comment": comment,
            "createdAt": Date().timeIntervalSince1970
        ]
        
        let ratingRef = database.child("ratings").child(order.id)
        
        ratingRef.setValue(ratingData) { error, _ in
            isSubmitting = false
            
            if let error = error {
                showError = true
                errorMessage = error.localizedDescription
                return
            }
            
            // Update the order with the rating
            let orderRef = database.child("orders").child(order.id)
            orderRef.updateChildValues(["rating": ratingData]) { error, _ in
                if let error = error {
                    showError = true
                    errorMessage = error.localizedDescription
                    return
                }
                
                dismiss()
            }
        }
    }
} 