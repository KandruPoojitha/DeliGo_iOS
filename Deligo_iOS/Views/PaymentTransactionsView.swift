import SwiftUI
import FirebaseDatabase
import Stripe

struct PaymentTransaction: Identifiable {
    let id: String
    let amount: Double
    let status: String
    let createdAt: TimeInterval
    let orderId: String
    let customerId: String?
    let restaurantId: String?
    let paymentMethod: String
    let source: String // "stripe" or "firebase"
    let stripePaymentIntentId: String?
    
    var formattedDate: String {
        let date = Date(timeIntervalSince1970: createdAt)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var formattedAmount: String {
        return String(format: "%.2f", amount)
    }
    
    var statusColor: Color {
        switch status.lowercased() {
        case "completed", "succeeded":
            return .green
        case "pending", "requires_payment_method":
            return .orange
        case "failed", "canceled":
            return .red
        default:
            return .gray
        }
    }
}

class PaymentTransactionsViewModel: ObservableObject {
    @Published var transactions: [PaymentTransaction] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var errorMessage: String?
    private let database = Database.database().reference()
    
    var filteredTransactions: [PaymentTransaction] {
        if searchText.isEmpty {
            return transactions
        }
        return transactions.filter { transaction in
            transaction.id.lowercased().contains(searchText.lowercased()) ||
            transaction.orderId.lowercased().contains(searchText.lowercased()) ||
            (transaction.stripePaymentIntentId?.lowercased().contains(searchText.lowercased()) ?? false)
        }
    }
    
    func loadTransactions() {
        isLoading = true
        transactions.removeAll()
        errorMessage = nil
        
        // Load Firebase transactions
        loadFirebaseTransactions()
        
        // Load Stripe transactions
        loadStripeTransactions()
    }
    
    private func loadFirebaseTransactions() {
        let paymentsRef = database.child("payments")
        paymentsRef.observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }
            
            for child in snapshot.children {
                guard let snapshot = child as? DataSnapshot,
                      let value = snapshot.value as? [String: Any] else { continue }
                
                let transaction = PaymentTransaction(
                    id: snapshot.key,
                    amount: value["amount"] as? Double ?? 0.0,
                    status: value["status"] as? String ?? "unknown",
                    createdAt: value["createdAt"] as? TimeInterval ?? 0,
                    orderId: value["orderId"] as? String ?? "",
                    customerId: value["customerId"] as? String,
                    restaurantId: value["restaurantId"] as? String,
                    paymentMethod: value["paymentMethod"] as? String ?? "unknown",
                    source: "firebase",
                    stripePaymentIntentId: value["stripePaymentIntentId"] as? String
                )
                
                DispatchQueue.main.async {
                    self.transactions.append(transaction)
                    self.sortTransactions()
                }
            }
        }
    }
    
    private func loadStripeTransactions() {
        // Create URL components for the Stripe API request
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.stripe.com"
        components.path = "/v1/payment_intents"
        
        // Create the request
        guard let url = components.url else {
            self.errorMessage = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        request.setValue("Bearer sk_test_51PlVh8P9Bz7XrwZPWSkDzX7AmaNgVr04yPOQWnbAECiYSWKtsmmVgD2Z8JYBY8a5dmEfKXaTewrBESb3fxIliwDo00HdJmKBKz", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Error loading Stripe transactions: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received from Stripe"
                    self.isLoading = false
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(StripePaymentIntentList.self, from: data)
                    
                    for intent in result.data {
                        let transaction = PaymentTransaction(
                            id: intent.id,
                            amount: Double(intent.amount) / 100.0, // Convert from cents to dollars
                            status: intent.status,
                            createdAt: TimeInterval(intent.created),
                            orderId: intent.metadata["orderId"] ?? "",
                            customerId: intent.customer,
                            restaurantId: intent.metadata["restaurantId"],
                            paymentMethod: intent.payment_method_types.first ?? "unknown",
                            source: "stripe",
                            stripePaymentIntentId: intent.id
                        )
                        
                        self.transactions.append(transaction)
                    }
                    
                    self.sortTransactions()
                    self.isLoading = false
                } catch {
                    self.errorMessage = "Error decoding Stripe data: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
        
        task.resume()
    }
    
    private func sortTransactions() {
        transactions.sort { $0.createdAt > $1.createdAt }
    }
}

// Stripe API Response Models
struct StripePaymentIntentList: Codable {
    let object: String
    let data: [StripePaymentIntent]
    let has_more: Bool
    let url: String
}

struct StripePaymentIntent: Codable {
    let id: String
    let object: String
    let amount: Int
    let created: Int
    let currency: String
    let customer: String?
    let status: String
    let payment_method_types: [String]
    let metadata: [String: String]
}

struct PaymentTransactionsView: View {
    @StateObject private var viewModel = PaymentTransactionsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search by Transaction ID", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading transactions...")
                    Spacer()
                } else if let errorMessage = viewModel.errorMessage {
                    Spacer()
                    VStack {
                        Text("Error")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry") {
                            viewModel.loadTransactions()
                        }
                        .foregroundColor(.blue)
                    }
                    .padding()
                    Spacer()
                } else if viewModel.filteredTransactions.isEmpty {
                    Spacer()
                    Text("No transactions found")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    List(viewModel.filteredTransactions) { transaction in
                        VStack(alignment: .leading, spacing: 8) {
                            // Transaction ID and Amount
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Transaction ID:")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Text(transaction.id)
                                        .font(.subheadline)
                                }
                                Spacer()
                                Text("$\(transaction.formattedAmount)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color(hex: "F4A261"))
                            }
                            
                    
                            
                            // Status and Date
                            HStack {
                                Text(transaction.status.capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(transaction.statusColor.opacity(0.2))
                                    .foregroundColor(transaction.statusColor)
                                    .cornerRadius(8)
                                
                                if transaction.source == "stripe" {
                                    Text("Stripe")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.2))
                                        .foregroundColor(.purple)
                                        .cornerRadius(8)
                                }
                                
                                Spacer()
                                
                                Text(transaction.formattedDate)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            // Payment Method
                            Text("Payment Method: \(transaction.paymentMethod.capitalized)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        viewModel.loadTransactions()
                    }
                }
            }
            .navigationTitle("Payment Transactions")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            viewModel.loadTransactions()
        }
    }
}

#Preview {
    PaymentTransactionsView()
} 
