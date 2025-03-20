import SwiftUI
import FirebaseDatabase

struct RestaurantChatView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var chatManager: ChatManager
    @State private var messageText = ""
    @State private var isLoading = true
    @State private var restaurantName = ""
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        
        // Create chat manager for restaurant user
        let userId = authViewModel.currentUserId ?? ""
        
        // We'll set a placeholder name and update it later
        _chatManager = StateObject(wrappedValue: ChatManager(
            userId: userId,
            userName: "Restaurant",
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
                            RestaurantMessageBubble(message: message, isFromCurrentUser: message.senderType != .admin)
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
            loadRestaurantInfo()
            loadMessages()
        }
    }
    
    private func loadRestaurantInfo() {
        guard let restaurantId = authViewModel.currentUserId else { return }
        
        let db = Database.database().reference()
        db.child("restaurants").child(restaurantId).observeSingleEvent(of: .value) { snapshot in
            guard let dict = snapshot.value as? [String: Any],
                  let name = dict["name"] as? String else { return }
            
            self.restaurantName = name
            
            // Update the chat manager with the restaurant name
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
        chatManager.sendMessage(threadId: threadId, message: messageText, userRole: "Restaurant") { success in
            if success {
                DispatchQueue.main.async {
                    self.messageText = ""
                }
            }
        }
    }
}

struct RestaurantMessageBubble: View {
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

struct RestaurantChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RestaurantChatView(authViewModel: AuthViewModel())
        }
    }
} 