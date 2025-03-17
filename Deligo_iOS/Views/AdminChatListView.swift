import SwiftUI
import FirebaseDatabase

struct AdminChatListView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var chatManager: ChatManager
    @State private var chatThreads: [ChatThread] = []
    @State private var isLoading = true
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        
        // Create a chat manager for the admin
        let userId = authViewModel.currentUserId ?? ""
        let userName = "Admin Support" // Fixed name for admin
        
        _chatManager = StateObject(wrappedValue: ChatManager(
            userId: userId,
            userName: userName,
            isAdmin: true
        ))
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading chat threads...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else if chatThreads.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No Support Requests")
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("When customers send messages, they will appear here")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                List {
                    ForEach(chatThreads) { thread in
                        NavigationLink(destination: AdminChatDetailView(authViewModel: authViewModel, thread: thread)) {
                            ChatThreadRow(thread: thread)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .refreshable {
                    loadChatThreads()
                }
            }
        }
        .navigationTitle("Support Chats")
        .onAppear {
            loadChatThreads()
        }
    }
    
    private func loadChatThreads() {
        isLoading = true
        
        chatManager.loadChatThreads { threads in
            DispatchQueue.main.async {
                self.chatThreads = threads
                self.isLoading = false
            }
        }
    }
}

struct ChatThreadRow: View {
    let thread: ChatThread
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(thread.customerName)
                    .font(.headline)
                
                Text(thread.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Format timestamp to a readable date
                Text(formatTimestamp(thread.lastMessageTimestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if thread.unreadCount > 0 {
                    Text("\(thread.unreadCount)")
                        .font(.caption)
                        .padding(6)
                        .background(Color(hex: "F4A261"))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTimestamp(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        
        // If today, show time only
        if Calendar.current.isDateInToday(date) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .none
        }
        
        return formatter.string(from: date)
    }
}

#Preview {
    AdminChatListView(authViewModel: AuthViewModel())
} 