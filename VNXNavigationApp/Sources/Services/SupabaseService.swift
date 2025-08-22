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
    
    private let supabase: SupabaseClient
    
    private init() {
        guard let supabaseURL = URL(string: SupabaseConfig.url) else {
            fatalError("Invalid Supabase URL")
        }
        
        self.supabase = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: SupabaseConfig.anonKey
        )
        
        Task {
            await checkAuthStatus()
        }
    }
    
    func checkAuthStatus() async {
        do {
            let session = try await supabase.auth.session
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
        
        let authResponse = try await supabase.auth.signUp(
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
        
        try await supabase
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
        
        let session = try await supabase.auth.signIn(
            email: email,
            password: password
        )
        
        let userId = session.user.id
        await fetchUserProfile(userId: userId)
        isAuthenticated = true
    }
    
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            isAuthenticated = false
            currentUser = nil
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    private func fetchUserProfile(userId: UUID) async {
        do {
            let response = try await supabase
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