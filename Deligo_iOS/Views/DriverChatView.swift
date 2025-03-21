import SwiftUI
import FirebaseDatabase

struct DriverChatView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var chatManager: ChatManager
    @State private var messageText = ""
    @State private var isLoading = true
    @State private var driverName = ""
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        
        // Create chat manager for driver user
        let userId = authViewModel.currentUserId ?? ""
        
        // We'll set a placeholder name and update it later
        _chatManager = StateObject(wrappedValue: ChatManager(
            userId: userId,
            userName: "Driver",
            isAdmin: false
        ))
    }
    
    var body: some View {
        VStack {
            // Messages list
            if isLoading {
                ProgressView("Loading messages...")
            } else if chatManager.messages.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No Messages Yet")
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("Start a conversation with support")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatManager.messages) { message in
                            DriverMessageBubble(message: message, isFromCurrentUser: message.senderType == .driver)
                        }
                    }
                    .padding()
                }
            }
            
            // Message input area
            HStack {
                TextField("Message support...", text: $messageText)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                        .padding(10)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle("Admin Support")
        .onAppear {
            loadDriverInfo()
            loadMessages()
        }
    }
    
    private func loadDriverInfo() {
        guard let driverId = authViewModel.currentUserId else { return }
        
        let db = Database.database().reference()
        db.child("drivers").child(driverId).observeSingleEvent(of: .value) { snapshot in
            guard let dict = snapshot.value as? [String: Any] else { return }
            
            // Try to get the driver's name using different possible field names
            let name = dict["name"] as? String ?? 
                       dict["fullName"] as? String ??
                       dict["driverName"] as? String ??
                       authViewModel.fullName ?? 
                       "Driver"
            
            self.driverName = name
            
            // Update the chat manager with the driver name
            self.chatManager.updateUserName(name)
        }
    }
    
    private func loadMessages() {
        isLoading = true
        let threadId = chatManager.getThreadId()
        chatManager.loadMessages(threadId: threadId)
        
        // Slight delay to allow messages to load
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isLoading = false
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let threadId = chatManager.getThreadId()
        chatManager.sendMessage(threadId: threadId, message: messageText, userRole: "Driver") { success in
            if success {
                DispatchQueue.main.async {
                    self.messageText = ""
                }
            }
        }
    }
}

struct DriverMessageBubble: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer() }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.senderName)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(message.message)
                    .padding(10)
                    .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(10)
                
                Text(message.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if !isFromCurrentUser { Spacer() }
        }
    }
}

struct DriverChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DriverChatView(authViewModel: AuthViewModel())
        }
    }
} 