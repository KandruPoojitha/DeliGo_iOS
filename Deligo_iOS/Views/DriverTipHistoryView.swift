import SwiftUI
import FirebaseDatabase

struct DriverTipHistoryView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var tips: [TipRecord] = []
    @State private var isLoading = true
    @State private var totalTips: Double = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Total Tips header
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Tips Earned")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("$\(String(format: "%.2f", totalTips))")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "F4A261"))
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            if isLoading {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView("Loading tip history...")
                    Spacer()
                }
                Spacer()
            } else if tips.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "dollarsign.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No Tips Yet")
                            .font(.title2)
                            .fontWeight(.medium)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Simple list of tips
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(tips) { tip in
                            // Simple card with order ID and amount
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Order #\(tip.orderId.prefix(8))-\(tip.orderId.dropFirst(8).prefix(4))-\(tip.orderId.dropFirst(12).prefix(4))-\(tip.orderId.dropFirst(16).prefix(4))-\(tip.orderId.dropFirst(20).prefix(8))")
                                    .font(.system(size: 16))
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                HStack {
                                    Text("Tip Amount")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    
                                    Spacer()
                                    
                                    Text("$\(String(format: "%.2f", tip.amount))")
                                        .font(.headline)
                                        .foregroundColor(Color(hex: "F4A261"))
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray5), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Tip History")
        .onAppear {
            loadTips()
        }
    }
    
    private func loadTips() {
        guard let driverId = authViewModel.currentUserId else {
            isLoading = false
            tips = []
            return
        }
        
        isLoading = true
        let database = Database.database().reference()
        
        // Query orders where driverId matches and tip exists
        database.child("orders")
            .queryOrdered(byChild: "driverId")
            .queryEqual(toValue: driverId)
            .observeSingleEvent(of: .value) { snapshot in
                var newTips: [TipRecord] = []
                self.totalTips = 0.0
                
                for child in snapshot.children {
                    guard let snapshot = child as? DataSnapshot,
                          let data = snapshot.value as? [String: Any],
                          let tip = data["tipAmount"] as? Double,
                          tip > 0,
                          let status = data["status"] as? String,
                          status == "delivered" else { continue }
                    
                    let orderId = snapshot.key
                    let date = Date(timeIntervalSince1970: data["updatedAt"] as? TimeInterval ?? 0)
                    
                    let record = TipRecord(
                        id: orderId,
                        orderId: orderId,
                        amount: tip,
                        date: date
                    )
                    
                    newTips.append(record)
                    self.totalTips += tip
                }
                
                // Sort tips by date, newest first
                newTips.sort { $0.date > $1.date }
                
                DispatchQueue.main.async {
                    self.tips = newTips
                    self.isLoading = false
                }
            }
    }
}

struct TipRecord: Identifiable {
    let id: String
    let orderId: String
    let amount: Double
    let date: Date
}

struct DriverTipHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DriverTipHistoryView(authViewModel: AuthViewModel())
        }
    }
} 