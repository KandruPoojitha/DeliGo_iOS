import Foundation
import UIKit
import StripePaymentSheet

class StripeManager {
    static let shared = StripeManager()
    
    private init() {}
    
    func handlePayment(amount: Double, completion: @escaping (Result<String, Error>) -> Void) {
        // Convert amount to cents
        let amountInCents = Int(amount * 100)
        
        // Create a payment intent on your server
        createPaymentIntent(amount: amountInCents) { result in
            switch result {
            case .success(let clientSecret):
                self.presentPaymentSheet(clientSecret: clientSecret) { result in
                    switch result {
                    case .success(let paymentIntentId):
                        completion(.success(paymentIntentId))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func createPaymentIntent(amount: Int, completion: @escaping (Result<String, Error>) -> Void) {
        // Replace with your server endpoint
        guard let url = URL(string: "YOUR_SERVER_ENDPOINT/create-payment-intent") else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["amount": amount, "currency": "usd"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let clientSecret = json["clientSecret"] as? String else {
                completion(.failure(NSError(domain: "Invalid response", code: -1)))
                return
            }
            
            completion(.success(clientSecret))
        }.resume()
    }
    
    private func presentPaymentSheet(clientSecret: String, completion: @escaping (Result<String, Error>) -> Void) {
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "DeliGo"
        configuration.allowsDelayedPaymentMethods = false
        
        let paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
        
        DispatchQueue.main.async {
            if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                paymentSheet.present(from: rootViewController) { result in
                    switch result {
                    case .completed:
                        // Extract payment intent ID from client secret
                        let paymentIntentId = String(clientSecret.split(separator: "_").first ?? "")
                        completion(.success(paymentIntentId))
                    case .canceled:
                        completion(.failure(NSError(domain: "Payment canceled", code: -1)))
                    case .failed(let error):
                        completion(.failure(error))
                    }
                }
            }
        }
    }
} 
