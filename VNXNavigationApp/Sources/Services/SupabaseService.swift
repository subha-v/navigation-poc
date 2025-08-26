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
            supabaseURL: clientURL,
            supabaseKey: SupabaseConfig.anonKey
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
        
        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )
            
            let userId = session.user.id
            await fetchUserProfile(userId: userId)
            isAuthenticated = true
        } catch {
            // If email not confirmed, try to sign up again (will auto-sign in if already exists)
            if error.localizedDescription.contains("not confirmed") || 
               error.localizedDescription.contains("Email not confirmed") {
                // For existing unconfirmed users, we can't bypass without Supabase settings
                errorMessage = "Email not confirmed. Please check Supabase Dashboard → Authentication → Users and manually confirm this email, or disable email confirmation in Authentication → Providers → Email settings."
                throw error
            } else {
                throw error
            }
        }
    }
    
    func signOut() async {
        do {
            try await client.auth.signOut()
            GoogleAuthService.shared.signOut()
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