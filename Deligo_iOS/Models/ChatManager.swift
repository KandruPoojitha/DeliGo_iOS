import Foundation
import FirebaseDatabase
import Combine

class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Database.database().reference()
    private let userId: String
    private let userName: String
    private let isAdmin: Bool
    private var chatRef: DatabaseReference
    private var threadsRef: DatabaseReference
    
    init(userId: String, userName: String, isAdmin: Bool) {
        self.userId = userId
        self.userName = userName
        self.isAdmin = isAdmin
        self.chatRef = db.child("chat_management").child("messages")
        self.threadsRef = db.child("chat_management").child("threads")
    }
    
    // Load messages for a specific chat thread
    func loadMessages(threadId: String) {
        guard !userId.isEmpty else {
            error = "Invalid user ID"
            return
        }
        
        isLoading = true
        print("Loading messages for thread: \(threadId)")
        
        chatRef.child(threadId).queryOrdered(byChild: "timestamp").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            self.isLoading = false
            
            var newMessages: [ChatMessage] = []
            
            for child in snapshot.children {
                guard let snapshot = child as? DataSnapshot,
                      let dict = snapshot.value as? [String: Any] else { continue }
                
                if let message = ChatMessage.fromDict(dict, id: snapshot.key) {
                    newMessages.append(message)
                    
                    // Mark message as read if it's from admin and user is customer
                    if !self.isAdmin && message.senderType == .admin && !message.isRead {
                        self.chatRef.child(threadId).child(message.id).child("isRead").setValue(true)
                    }
                }
            }
            
            // Sort messages by timestamp
            newMessages.sort { $0.timestamp < $1.timestamp }
            
            DispatchQueue.main.async {
                self.messages = newMessages
            }
        }
    }
    
    // Send a new message
    func sendMessage(threadId: String, message: String, completion: @escaping (Bool) -> Void) {
        guard !userId.isEmpty, !message.isEmpty else {
            error = "Invalid user ID or empty message"
            completion(false)
            return
        }
        
        let messageId = chatRef.child(threadId).childByAutoId().key ?? UUID().uuidString
        let timestamp = Date().timeIntervalSince1970 * 1000
        
        let newMessage = ChatMessage(
            id: messageId,
            senderId: userId,
            senderName: userName,
            senderType: isAdmin ? .admin : .customer,
            message: message,
            timestamp: timestamp,
            isRead: false
        )
        
        // Update the thread with last message info
        let threadUpdate: [String: Any] = [
            "lastMessage": message,
            "lastMessageTimestamp": timestamp,
            "unreadCount": ServerValue.increment(isAdmin ? 1 : 0) // Increment unread count if admin is sending
        ]
        
        // If this is a new thread from a customer, create the thread
        if !isAdmin && !threadExists(threadId: threadId) {
            let newThread: [String: Any] = [
                "customerId": userId,
                "customerName": userName,
                "lastMessage": message,
                "lastMessageTimestamp": timestamp,
                "unreadCount": 0
            ]
            threadsRef.child(threadId).setValue(newThread)
        } else {
            threadsRef.child(threadId).updateChildValues(threadUpdate)
        }
        
        // Save the message
        chatRef.child(threadId).child(messageId).setValue(newMessage.toDict()) { error, _ in
            if let error = error {
                self.error = "Failed to send message: \(error.localizedDescription)"
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    // Check if a thread exists
    private func threadExists(threadId: String) -> Bool {
        // This is a simplification - in a real app, you'd check Firebase
        // For now, we'll assume the thread exists if we have messages
        return !messages.isEmpty
    }
    
    // Load all chat threads (for admin view)
    func loadChatThreads(completion: @escaping ([ChatThread]) -> Void) {
        guard isAdmin else {
            completion([])
            return
        }
        
        threadsRef.observeSingleEvent(of: .value) { snapshot in
            var threads: [ChatThread] = []
            
            for child in snapshot.children {
                guard let snapshot = child as? DataSnapshot,
                      let dict = snapshot.value as? [String: Any] else { continue }
                
                if let thread = ChatThread.fromDict(dict, id: snapshot.key) {
                    threads.append(thread)
                }
            }
            
            // Sort threads by last message timestamp (newest first)
            threads.sort { $0.lastMessageTimestamp > $1.lastMessageTimestamp }
            
            completion(threads)
        }
    }
    
    // Get or create a thread ID for a customer
    func getThreadId() -> String {
        if isAdmin {
            fatalError("Admin cannot create a thread ID")
        }
        return userId // Using customer ID as thread ID for simplicity
    }
    
    // Mark all messages in a thread as read
    func markThreadAsRead(threadId: String) {
        guard isAdmin else { return }
        
        // Update the unread count in the thread
        threadsRef.child(threadId).child("unreadCount").setValue(0)
        
        // Mark all messages as read
        chatRef.child(threadId).observeSingleEvent(of: .value) { snapshot in
            for child in snapshot.children {
                guard let snapshot = child as? DataSnapshot,
                      let dict = snapshot.value as? [String: Any],
                      let isRead = dict["isRead"] as? Bool,
                      !isRead else { continue }
                
                self.chatRef.child(threadId).child(snapshot.key).child("isRead").setValue(true)
            }
        }
    }
} 