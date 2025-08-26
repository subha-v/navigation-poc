import Foundation
import Supabase
import Combine

@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let client: SupabaseClient  // Make public for GoogleAuthService
    
    private init() {
        guard let clientURL = URL(string: SupabaseConfig.url) else {
            fatalError("Invalid Supabase URL")
        }
        
        self.client = SupabaseClient(
            clientURL: clientURL,
            clientKey: SupabaseConfig.anonKey
        )
        
        Task {
            await checkAuthStatus()
        }
    }
    
    func checkAuthStatus() async {
        do {
            let session = try await client.auth.session
            isAuthenticated = true
            let userId = session.user.id
            await fetchUserProfile(userId: userId)
        } catch {
            print("No active session: \(error)")
            isAuthenticated = false
        }
    }
    
    func signUp(email: String, password: String, role: UserRole) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        let authResponse = try await client.auth.signUp(
            email: email,
            password: password,
            data: [:]
        )
        
        let userId = authResponse.user.id
        
        let newUser = User(
            id: userId,
            email: email,
            role: role,
            anchorLocation: nil,
            createdAt: Date()
        )
        
        try await client
            .from("users")
            .insert(newUser)
            .execute()
        
        currentUser = newUser
        isAuthenticated = true
    }
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )
        
        let userId = session.user.id
        await fetchUserProfile(userId: userId)
        isAuthenticated = true
    }
    
    func signOut() async {
        do {
            try await client.auth.signOut()
            try? await GoogleAuthService.shared.signOut()
            isAuthenticated = false
            currentUser = nil
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    func setCurrentUser(_ user: User) async {
        self.currentUser = user
        self.isAuthenticated = true
    }
    
    private func fetchUserProfile(userId: UUID) async {
        do {
            let response = try await client
                .from("users")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
            
            let user = try JSONDecoder().decode(User.self, from: response.data)
            currentUser = user
        } catch {
            print("Error fetching user profile: \(error)")
        }
    }
}