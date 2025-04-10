import SwiftUI
import Charts
import FirebaseDatabase

struct SalesReportsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedPeriod: TimePeriod = .week
    @State private var totalRevenue: Double = 0
    @State private var totalOrders: Int = 0
    @State private var averageOrderValue: Double = 0
    @State private var revenueData: [(Date, Double)] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let database = Database.database().reference()
    
    enum TimePeriod: String, CaseIterable {
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
        case year = "This Year"
    }
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period selector
                Picker("Time Period", selection: $selectedPeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if isLoading {
                    ProgressView("Loading sales data...")
                        .frame(maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.red)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    // Metric cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        MetricCard(title: "Total Revenue", value: String(format: "$%.2f", totalRevenue))
                        MetricCard(title: "Total Orders", value: "\(totalOrders)")
                        MetricCard(title: "Average Order", value: String(format: "$%.2f", averageOrderValue))
                    }
                    .padding(.horizontal)
                    
                    // Revenue chart
                    VStack(alignment: .leading) {
                        Text("Revenue Trend")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Chart {
                            ForEach(revenueData, id: \.0) { item in
                                LineMark(
                                    x: .value("Date", item.0),
                                    y: .value("Revenue", item.1)
                                )
                                .foregroundStyle(Color(hex: "F4A261"))
                            }
                        }
                        .frame(height: 200)
                        .padding()
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Sales Reports")
        .onAppear {
            loadSalesData()
        }
        .onChange(of: selectedPeriod) { _, _ in
            loadSalesData()
        }
    }
    
    private func loadSalesData() {
        guard let restaurantId = authViewModel.currentUserId else {
            errorMessage = "Restaurant ID not found"
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Calculate date range based on selected period
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        
        switch selectedPeriod {
        case .day:
            startDate = calendar.startOfDay(for: now)
        case .week:
            startDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        case .month:
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        case .year:
            startDate = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        }
        
        // Convert dates to timestamps
        let startTimestamp = Int(startDate.timeIntervalSince1970 * 1000)
        let endTimestamp = Int(now.timeIntervalSince1970 * 1000)
        
        // Query orders
        let ordersRef = database.child("orders")
        ordersRef.observe(.value) { snapshot in
            print("Received snapshot with \(snapshot.childrenCount) orders")
            var orders: [(Date, Double)] = []
            var totalRev: Double = 0
            var orderCount = 0
            
            for child in snapshot.children {
                guard let orderSnapshot = child as? DataSnapshot else { continue }
                
                // Get the order details
                guard let orderData = orderSnapshot.value as? [String: Any] else {
                    print("Failed to parse order data for ID: \(orderSnapshot.key)")
                    continue
                }
                
                // Debug print
                print("Processing order: \(orderSnapshot.key)")
                print("Order data: \(orderData)")
                
                // Check if this order belongs to the current restaurant
                guard let restaurantIdFromOrder = orderData["restaurantId"] as? String,
                      restaurantIdFromOrder == restaurantId else {
                    print("Restaurant ID mismatch: \(String(describing: orderData["restaurantId"]))")
                    continue
                }
                
                // Check if the order is delivered
                guard let status = orderData["status"] as? String,
                      status == "delivered" else {
                    print("Order not delivered: \(String(describing: orderData["status"]))")
                    continue
                }
                
                // Get the timestamp from updatedAt
                guard let updatedAt = orderData["updatedAt"] as? Double else {
                    print("Missing updatedAt timestamp")
                    continue
                }
                
                // Calculate total from items
                var subtotal: Double = 0
                if let items = orderData["items"] as? [[String: Any]] {
                    for item in items {
                        if let price = item["price"] as? Double,
                           let quantity = item["quantity"] as? Int {
                            subtotal += price * Double(quantity)
                        }
                    }
                }
                
                // Add delivery fee if it exists
                if let deliveryFee = orderData["deliveryFee"] as? Double {
                    subtotal += deliveryFee
                }
                
                // Filter by timestamp after fetching
                if updatedAt >= Double(startTimestamp) && updatedAt <= Double(endTimestamp) {
                    let date = Date(timeIntervalSince1970: updatedAt / 1000)
                    orders.append((date, subtotal))
                    totalRev += subtotal
                    orderCount += 1
                    print("Added order with amount: \(subtotal) at date: \(date)")
                }
            }
            
            // Sort orders by date
            orders.sort { $0.0 < $1.0 }
            
            // Group orders by day for the chart
            var groupedData: [(Date, Double)] = []
            var currentDate = startDate
            var currentTotal: Double = 0
            
            for order in orders {
                if calendar.isDate(order.0, inSameDayAs: currentDate) {
                    currentTotal += order.1
                } else {
                    if currentTotal > 0 {
                        groupedData.append((currentDate, currentTotal))
                    }
                    currentDate = order.0
                    currentTotal = order.1
                }
            }
            if currentTotal > 0 {
                groupedData.append((currentDate, currentTotal))
            }
            
            DispatchQueue.main.async {
                self.revenueData = groupedData
                self.totalRevenue = totalRev
                self.totalOrders = orderCount
                self.averageOrderValue = orderCount > 0 ? totalRev / Double(orderCount) : 0
                self.isLoading = false
                
                // Debug print
                print("Updated UI with: Revenue: \(totalRev), Orders: \(orderCount), Average: \(self.averageOrderValue)")
            }
        } withCancel: { error in
            DispatchQueue.main.async {
                self.errorMessage = "Error loading sales data: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    NavigationView {
        SalesReportsView(authViewModel: AuthViewModel())
    }
} 