import SwiftUI
import FirebaseDatabase
import Charts

struct DriverEarningsHistoryView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var earnings: [EarningRecord] = []
    @State private var isLoading = true
    @State private var timeFrame: TimeFrame = .week
    @State private var totalEarnings: Double = 0.0
    @State private var totalDeliveries: Int = 0
    
    enum TimeFrame: String, CaseIterable, Identifiable {
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        VStack {
            // Time frame picker
            Picker("Time Frame", selection: $timeFrame) {
                ForEach(TimeFrame.allCases) { timeFrame in
                    Text(timeFrame.rawValue).tag(timeFrame)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: timeFrame) { _, _ in
                loadEarnings()
            }
            
            // Earnings summary cards
            HStack(spacing: 12) {
                // Total earnings card
                VStack(alignment: .leading) {
                    Text("Total Earnings")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("$\(String(format: "%.2f", totalEarnings))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "F4A261"))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Total deliveries card
                VStack(alignment: .leading) {
                    Text("Deliveries")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("\(totalDeliveries)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            if isLoading {
                Spacer()
                ProgressView("Loading earnings...")
                Spacer()
            } else if earnings.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "banknote")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No Earnings Yet")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Earnings from your deliveries will appear here")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
            } else {
                // Charts will only be available on iOS 16+
                if #available(iOS 16.0, *) {
                    // Chart view
                    Chart {
                        ForEach(groupedEarningsByDay()) { day in
                            BarMark(
                                x: .value("Day", day.day),
                                y: .value("Amount", day.amount)
                            )
                            .foregroundStyle(Color(hex: "F4A261"))
                        }
                    }
                    .frame(height: 200)
                    .padding()
                }
                
                // Earnings list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(earnings) { earning in
                            earningCard(earning)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Earnings History")
        .onAppear {
            loadEarnings()
        }
    }
    
    private func earningCard(_ earning: EarningRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(earning.restaurantName)
                    .font(.headline)
                
                Text("Order #\(earning.orderId.prefix(6))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(formattedDate(from: earning.date))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", earning.amount))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "F4A261"))
                
                if earning.tipAmount > 0 {
                    Text("Tip: $\(String(format: "%.2f", earning.tipAmount))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func loadEarnings() {
        guard let driverId = authViewModel.currentUserId else {
            isLoading = false
            earnings = []
            return
        }
        
        isLoading = true
        let database = Database.database().reference()
        
        // Query orders where driverId matches
        database.child("orders")
            .queryOrdered(byChild: "driverId")
            .queryEqual(toValue: driverId)
            .observeSingleEvent(of: .value) { snapshot in
                var newEarnings: [EarningRecord] = []
                self.totalEarnings = 0.0
                self.totalDeliveries = 0
                
                for child in snapshot.children {
                    guard let snapshot = child as? DataSnapshot,
                          let data = snapshot.value as? [String: Any],
                          let status = data["status"] as? String,
                          status.lowercased() == "delivered" else { continue }
                    
                    let orderId = snapshot.key
                    let restaurantName = data["restaurantName"] as? String ?? "Restaurant"
                    let createdAt = data["createdAt"] as? TimeInterval ?? 0
                    let date = Date(timeIntervalSince1970: createdAt)
                    
                    // Delivery fee can be a fixed amount per delivery
                    let deliveryFee = data["deliveryFee"] as? Double ?? 3.99
                    
                    // Driver tip if available
                    let tipAmount = data["driverTip"] as? Double ?? 0.0
                    
                    // Total earning is delivery fee + tip
                    let totalAmount = deliveryFee + tipAmount
                    
                    // Filter by time frame
                    if isWithinTimeFrame(date: date) {
                        let record = EarningRecord(
                            id: orderId,
                            orderId: orderId,
                            restaurantName: restaurantName,
                            amount: totalAmount,
                            tipAmount: tipAmount,
                            deliveryFee: deliveryFee,
                            date: date
                        )
                        
                        newEarnings.append(record)
                        self.totalEarnings += totalAmount
                        self.totalDeliveries += 1
                    }
                }
                
                // Sort earnings by date, newest first
                newEarnings.sort { $0.date > $1.date }
                
                DispatchQueue.main.async {
                    self.earnings = newEarnings
                    self.isLoading = false
                }
            }
    }
    
    private func isWithinTimeFrame(date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeFrame {
        case .day:
            return calendar.isDate(date, inSameDayAs: now)
            
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return date >= weekAgo
            
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return date >= monthAgo
            
        case .all:
            return true
        }
    }
    
    private func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    @available(iOS 16.0, *)
    private func groupedEarningsByDay() -> [DayEarning] {
        let calendar = Calendar.current
        var dayEarnings: [String: Double] = [:]
        
        // Group earnings by day
        for earning in earnings {
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: earning.date)
            if let date = calendar.date(from: dateComponents) {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd"
                let dateString = formatter.string(from: date)
                
                dayEarnings[dateString, default: 0] += earning.amount
            }
        }
        
        // Convert to array for chart
        let sortedDays = dayEarnings.keys.sorted { key1, key2 in
            // Parse the date strings back to Date objects for comparison
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            let date1 = formatter.date(from: key1) ?? Date()
            let date2 = formatter.date(from: key2) ?? Date()
            return date1 < date2
        }
        
        return sortedDays.map { day in
            DayEarning(day: day, amount: dayEarnings[day] ?? 0)
        }
    }
}

struct DayEarning: Identifiable {
    let id = UUID()
    let day: String
    let amount: Double
}

struct EarningRecord: Identifiable {
    let id: String
    let orderId: String
    let restaurantName: String
    let amount: Double
    let tipAmount: Double
    let deliveryFee: Double
    let date: Date
}

struct DriverEarningsHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DriverEarningsHistoryView(authViewModel: AuthViewModel())
        }
    }
} 