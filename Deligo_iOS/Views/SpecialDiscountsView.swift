import SwiftUI
import FirebaseDatabase

struct SpecialDiscountsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedPercentage = 10
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    
    private let percentageOptions = [10, 20, 30, 40, 50]
    private let database = Database.database().reference()
    
    var body: some View {
        Form {
            if isLoading {
                ProgressView("Loading discount...")
            } else {
                Section {
                    Picker("Select Discount", selection: $selectedPercentage) {
                        ForEach(percentageOptions, id: \.self) { percentage in
                            Text("\(percentage)%").tag(percentage)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .navigationTitle("Special Discount")
        .navigationBarItems(trailing: Button("Done") {
            updateDiscount(percentage: selectedPercentage)
            dismiss()
        })
        .onAppear {
            loadCurrentDiscount()
        }
    }
    
    private func loadCurrentDiscount() {
        guard let restaurantId = authViewModel.currentUserId else { return }
        
        isLoading = true
        database.child("restaurants").child(restaurantId).child("discount").observe(.value) { snapshot in
            if let value = snapshot.value as? Int {
                self.selectedPercentage = value
            }
            self.isLoading = false
        }
    }
    
    private func updateDiscount(percentage: Int) {
        guard let restaurantId = authViewModel.currentUserId else { return }
        database.child("restaurants").child(restaurantId).child("discount").setValue(percentage)
    }
}

#Preview {
    NavigationView {
        SpecialDiscountsView(authViewModel: AuthViewModel())
    }
} 