import SwiftUI
import FirebaseDatabase

struct GroupChatView: View {
    let orderId: String
    @ObservedObject var authViewModel: AuthViewModel
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = true
    @State private var participants: [String: String] = [:] // [userId: userName]
    @Environment(\.presentationMode) var presentationMode
    
    private let database = Database.database().reference()
    
    var body: some View {
        VStack {
            // Chat header
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Text("Group Chat")
                    .font(.headline)
                    .padding(.leading, 8)
                
                Spacer()
                
                Text("Order #\(orderId.prefix(8))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding()
            
            // Participants list
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(participants.keys), id: \.self) { userId in
                        VStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                            Text(participants[userId] ?? "Unknown")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            if isLoading {
                Spacer()
                ProgressView("Loading conversation...")
                Spacer()
            } else if messages.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No messages yet")
                        .font(.headline)
                    Text("Start a conversation with the group")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                // Messages list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            GroupMessageBubble(
                                message: message,
                                isFromCurrentUser: message.senderId == authViewModel.currentUserId,
                                senderName: participants[message.senderId] ?? "Unknown"
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
            }
            
            // Message input
            HStack {
                TextField("Type a message...", text: $messageText)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : Color(hex: "F4A261"))
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.leading, 8)
            }
            .padding()
        }
        .onAppear {
            loadParticipants()
            loadMessages()
        }
        .navigationBarHidden(true)
    }
    
    private func loadParticipants() {
        let orderRef = database.child("orders").child(orderId)
        
        // Load customer
        orderRef.child("userId").observeSingleEvent(of: .value) { snapshot in
            if let customerId = snapshot.value as? String {
                database.child("customers").child(customerId).observeSingleEvent(of: .value) { customerSnapshot in
                    if let customerData = customerSnapshot.value as? [String: Any],
                       let customerName = customerData["fullName"] as? String {
                        print("DEBUG: Loaded customer: \(customerName)")
                        DispatchQueue.main.async {
                            self.participants[customerId] = customerName
                        }
                    }
                }
            }
        }
        
        // Load restaurant
        orderRef.child("restaurantId").observeSingleEvent(of: .value) { snapshot in
            if let restaurantId = snapshot.value as? String {
                database.child("restaurants").child(restaurantId).child("store_info").observeSingleEvent(of: .value) { restaurantSnapshot in
                    if let restaurantData = restaurantSnapshot.value as? [String: Any],
                       let restaurantName = restaurantData["name"] as? String {
                        print("DEBUG: Loaded restaurant: \(restaurantName)")
                        DispatchQueue.main.async {
                            self.participants[restaurantId] = restaurantName
                        }
                    }
                }
            }
        }
        
        // Load driver
        orderRef.child("driverId").observeSingleEvent(of: .value) { snapshot in
            if let driverId = snapshot.value as? String {
                database.child("drivers").child(driverId).observeSingleEvent(of: .value) { driverSnapshot in
                    if let driverData = driverSnapshot.value as? [String: Any] {
                        // Try different possible field names for driver name
                        let driverName = driverData["fullName"] as? String ??
                                       driverData["name"] as? String ??
                                       driverData["driverName"] as? String
                        
                        if let name = driverName {
                            print("DEBUG: Loaded driver: \(name)")
                            DispatchQueue.main.async {
                                self.participants[driverId] = name
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func loadMessages() {
        isLoading = true
        
        // Reference to the group chat messages
        let messagesRef = database.child("orders").child(orderId).child("group_chat")
        
        // Listen for messages
        messagesRef.observe(.value) { snapshot in
            var newMessages: [ChatMessage] = []
            
            for child in snapshot.children {
                guard let messageSnapshot = child as? DataSnapshot,
                      let messageData = messageSnapshot.value as? [String: Any] else { continue }
                
                let message = ChatMessage(id: messageSnapshot.key, data: messageData)
                newMessages.append(message)
                
                // Make sure we have the sender in participants
                if let senderId = messageData["senderId"] as? String,
                   let senderName = messageData["senderName"] as? String,
                   self.participants[senderId] == nil {
                    self.participants[senderId] = senderName
                }
            }
            
            // Sort messages by timestamp
            newMessages.sort { $0.timestamp < $1.timestamp }
            
            DispatchQueue.main.async {
                self.messages = newMessages
                self.isLoading = false
            }
        }
    }
    
    private func sendMessage() {
        // Debug prints
        print("DEBUG: Attempting to send message")
        print("DEBUG: Current User ID: \(authViewModel.currentUserId ?? "nil")")
        print("DEBUG: Current User Role: \(authViewModel.currentUserRole?.rawValue ?? "nil")")
        print("DEBUG: Current User Name: \(authViewModel.fullName ?? "nil")")
        
        guard let userId = authViewModel.currentUserId,
              let userName = authViewModel.fullName,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("DEBUG: Failed to send - missing required fields")
            print("DEBUG: userId exists: \(authViewModel.currentUserId != nil)")
            print("DEBUG: userName exists: \(authViewModel.fullName != nil)")
            print("DEBUG: message not empty: \(!messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)")
            return
        }
        
        let messagesRef = database.child("orders").child(orderId).child("group_chat")
        let newMessageRef = messagesRef.childByAutoId()
        
        // Convert role to lowercase for consistency
        let senderType = authViewModel.currentUserRole?.rawValue.lowercased() ?? "unknown"
        print("DEBUG: Sender type: \(senderType)")
        
        let message = [
            "senderId": userId,
            "senderName": userName,
            "senderType": senderType,
            "message": messageText.trimmingCharacters(in: .whitespacesAndNewlines),
            "timestamp": ServerValue.timestamp()
        ] as [String: Any]
        
        print("DEBUG: Sending message with data: \(message)")
        
        newMessageRef.setValue(message) { error, _ in
            if let error = error {
                print("DEBUG: Error sending message: \(error.localizedDescription)")
            } else {
                print("DEBUG: Message sent successfully!")
                // Clear the input field
                DispatchQueue.main.async {
                    self.messageText = ""
                }
            }
        }
    }
}

struct GroupMessageBubble: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    let senderName: String
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(senderName)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(message.message)
                    .padding(12)
                    .background(isFromCurrentUser ? Color(hex: "F4A261") : Color(.systemGray5))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isFromCurrentUser ? .trailing : .leading)
                
                Text(message.formattedTime)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }
            
            if !isFromCurrentUser {
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    GroupChatView(
        orderId: "order123",
        authViewModel: AuthViewModel()
    )
} 