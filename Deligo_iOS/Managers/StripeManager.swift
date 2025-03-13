import Foundation
import UIKit
import StripePaymentSheet

class StripeManager {
    static let shared = StripeManager()
    @Published var paymentSheet: PaymentSheet?
    @Published var paymentResult: PaymentSheetResult?
    private var currentClientSecret: String?
    
    private init() {
        StripeAPI.defaultPublishableKey = "pk_test_51PlVh8P9Bz7XrwZPnWMN2upZk3x00s3soZgJgM5QTMuwCNoZPBdGtmPRXB29vBnFvOXjEAv2vntLuQaWbPpEHOmP00D7pelv0B"
    }
    
    func preparePaymentSheet(amount: Double, completion: @escaping (Result<PaymentSheet, Error>) -> Void) {
        let amountInCents = Int(amount * 100)
        
        print("Preparing payment sheet for amount: \(amountInCents) cents")
        
        guard let url = URL(string: "http://localhost:3000/create-payment-intent") else {
            let error = NSError(domain: "StripeError",
                              code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            completion(.failure(error))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "amount": amountInCents,
            "currency": "cad"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("Calling create-payment-intent with data:", body)
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Network error creating payment intent:", error.localizedDescription)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(domain: "StripeError",
                                  code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = json["error"] as? String {
                    let error = NSError(domain: "StripeError",
                                      code: httpResponse.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                } else {
                    let error = NSError(domain: "StripeError",
                                      code: httpResponse.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
                return
            }
            
            guard let data = data else {
                let error = NSError(domain: "StripeError",
                                  code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "No data received"])
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let clientSecret = json?["clientSecret"] as? String else {
                    throw NSError(domain: "StripeError",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
                }
                
                print("Successfully received client secret")
                self?.currentClientSecret = clientSecret
                
                var configuration = PaymentSheet.Configuration()
                configuration.merchantDisplayName = "DeliGo"
                configuration.defaultBillingDetails.address.country = "CA"
                configuration.allowsDelayedPaymentMethods = false
                
                let paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
                self?.paymentSheet = paymentSheet
                
                print("Payment sheet created successfully")
                DispatchQueue.main.async {
                    completion(.success(paymentSheet))
                }
            } catch {
                print("Error parsing response:", error.localizedDescription)
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw response:", responseString)
                }
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    func handlePayment(amount: Double, completion: @escaping (Result<String, Error>) -> Void) {
        print("Starting payment process for amount:", amount)
        
        preparePaymentSheet(amount: amount) { [weak self] result in
            switch result {
            case .success(let paymentSheet):
                print("Payment sheet prepared successfully")
                
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    let error = NSError(domain: "StripeError",
                                      code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "No root view controller found"])
                    print("Error:", error.localizedDescription)
                    completion(.failure(error))
                    return
                }
                
                DispatchQueue.main.async {
                    print("Presenting payment sheet")
                    paymentSheet.present(from: rootViewController) { paymentResult in
                        print("Payment result received:", paymentResult)
                        
                        switch paymentResult {
                        case .completed:
                            if let clientSecret = self?.currentClientSecret,
                               let paymentIntentId = clientSecret.components(separatedBy: "_secret_").first {
                                print("Payment completed successfully with ID:", paymentIntentId)
                                completion(.success(paymentIntentId))
                            } else {
                                let error = NSError(domain: "StripeError",
                                                  code: -1,
                                                  userInfo: [NSLocalizedDescriptionKey: "Could not extract payment intent ID"])
                                print("Error:", error.localizedDescription)
                                completion(.failure(error))
                            }
                        case .canceled:
                            let error = NSError(domain: "StripeError",
                                              code: -1,
                                              userInfo: [NSLocalizedDescriptionKey: "Payment canceled by user"])
                            print("Payment canceled by user")
                            completion(.failure(error))
                        case .failed(let error):
                            print("Payment failed:", error.localizedDescription)
                            completion(.failure(error))
                        }
                    }
                }
            case .failure(let error):
                print("Failed to prepare payment sheet:", error.localizedDescription)
                completion(.failure(error))
            }
        }
    }
} 
