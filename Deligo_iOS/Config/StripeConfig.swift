import Foundation

enum StripeConfig {
    static let publishableKey = "pk_test_51PlVh8P9Bz7XrwZPnWMN2upZk3x00s3soZgJgM5QTMuwCNoZPBdGtmPRXB29vBnFvOXjEAv2vntLuQaWbPpEHOmP00D7pelv0B"
    
    // Base URL for your backend API
    static let apiBaseURL = "https://your-backend-api.com"  // Replace with your backend URL
    
    // Endpoints
    static let paymentIntentsEndpoint = "\(apiBaseURL)/api/payment-intents"
} 