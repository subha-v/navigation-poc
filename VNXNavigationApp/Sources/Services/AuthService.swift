import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    private init() {
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        authStateListener = auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                if let firebaseUser = firebaseUser {
                    await self?.loadUserData(firebaseUser: firebaseUser)
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
            }
        }
    }
    
    @MainActor
    private func loadUserData(firebaseUser: FirebaseAuth.User) async {
        do {
            let document = try await db.collection("users").document(firebaseUser.uid).getDocument()
            
            if document.exists {
                let data = document.data()
                let roleString = data?["role"] as? String ?? ""
                let role = UserRole(rawValue: roleString)
                
                currentUser = User(
                    id: firebaseUser.uid,
                    email: firebaseUser.email ?? "",
                    fullName: data?["fullName"] as? String,
                    role: role,
                    createdAt: (data?["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )
                isAuthenticated = true
            } else {
                currentUser = User(
                    id: firebaseUser.uid,
                    email: firebaseUser.email ?? "",
                    fullName: nil,
                    role: nil,
                    createdAt: Date()
                )
                isAuthenticated = true
            }
        } catch {
            print("Error loading user data: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func signUp(email: String, password: String, fullName: String, role: UserRole) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            
            let userData: [String: Any] = [
                "email": email,
                "fullName": fullName,
                "role": role.rawValue,
                "createdAt": Timestamp(date: Date())
            ]
            
            try await db.collection("users").document(result.user.uid).setData(userData)
            
            currentUser = User(
                id: result.user.uid,
                email: email,
                fullName: fullName,
                role: role,
                createdAt: Date()
            )
            isAuthenticated = true
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    @MainActor
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await auth.signIn(withEmail: email, password: password)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    @MainActor
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await auth.sendPasswordReset(withEmail: email)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signOut() throws {
        try auth.signOut()
        currentUser = nil
        isAuthenticated = false
    }
}