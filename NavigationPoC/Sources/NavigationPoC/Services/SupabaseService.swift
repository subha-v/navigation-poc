import Foundation
import Supabase
import Combine

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase: SupabaseClient
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Credentials are loaded from SupabaseConfig.swift (not in version control)
        guard let supabaseURL = URL(string: SupabaseConfig.url) else {
            fatalError("Invalid Supabase URL in SupabaseConfig.swift")
        }
        
        self.supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: SupabaseConfig.anonKey)
        
        Task {
            await checkAuthStatus()
        }
    }
    
    @MainActor
    func checkAuthStatus() async {
        do {
            let session = try await supabase.auth.session
            isAuthenticated = session != nil
            if let userId = session?.user.id {
                await fetchUserProfile(userId: userId)
            }
        } catch {
            print("Error checking auth status: \(error)")
            isAuthenticated = false
        }
    }
    
    @MainActor
    func signUp(email: String, password: String, role: UserRole) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let authResponse = try await supabase.auth.signUp(email: email, password: password, data: [:])
            
            guard let userId = authResponse.user?.id else {
                throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get user ID"])
            }
            
            // Create user profile
            let newUser = User(
                id: userId,
                email: email,
                role: role,
                anchorLocation: nil,
                createdAt: Date()
            )
            
            try await supabase.database
                .from("users")
                .insert(newUser)
                .execute()
            
            currentUser = newUser
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
            let session = try await supabase.auth.signIn(email: email, password: password)
            
            guard let userId = session.user?.id else {
                throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get user ID"])
            }
            
            await fetchUserProfile(userId: userId)
            isAuthenticated = true
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    @MainActor
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            isAuthenticated = false
            currentUser = nil
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    @MainActor
    func assignAnchorLocation(_ location: String) async throws {
        guard var user = currentUser else { return }
        
        user.anchorLocation = location
        
        try await supabase.database
            .from("users")
            .update(["anchor_location": location])
            .eq("id", value: user.id.uuidString)
            .execute()
        
        currentUser = user
    }
    
    @MainActor
    private func fetchUserProfile(userId: UUID) async {
        do {
            let response = try await supabase.database
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
    
    @MainActor
    func saveNavigationRating(destination: String, rating: Int, feedback: String?) async {
        guard let userId = currentUser?.id else { return }
        
        let ratingData: [String: Any] = [
            "user_id": userId.uuidString,
            "destination": destination,
            "rating": rating,
            "feedback": feedback ?? "",
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            try await supabase.database
                .from("navigation_ratings")
                .insert(ratingData)
                .execute()
        } catch {
            print("Error saving rating: \(error)")
        }
    }
}