import Foundation
import GoogleSignIn
import Supabase
import UIKit

@MainActor
class GoogleAuthService: ObservableObject {
    static let shared = GoogleAuthService()
    
    private let supabase = SupabaseService.shared.client
    
    private init() {}
    
    func signInWithGoogle(presenting viewController: UIViewController) async throws -> User? {
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { [weak self] result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = result,
                      let idToken = result.user.idToken?.tokenString else {
                    continuation.resume(throwing: AuthError.invalidCredentials)
                    return
                }
                
                let user = result.user
                let email = user.profile?.email ?? ""
                let name = user.profile?.name ?? ""
                
                Task {
                    do {
                        let authResponse = try await self?.supabase.auth.signInWithIdToken(
                            credentials: .init(
                                provider: .google,
                                idToken: idToken
                            )
                        )
                        
                        guard let authUser = authResponse?.user else {
                            continuation.resume(throwing: AuthError.invalidCredentials)
                            return
                        }
                        
                        let vnxUser = User(
                            id: authUser.id,
                            email: email,
                            name: name,
                            role: nil
                        )
                        
                        continuation.resume(returning: vnxUser)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
    
    func restorePreviousSignIn() async throws -> User? {
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let user = user,
                      let idToken = user.idToken?.tokenString,
                      let email = user.profile?.email else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let name = user.profile?.name ?? ""
                
                Task { [weak self] in
                    do {
                        let authResponse = try await self?.supabase.auth.signInWithIdToken(
                            credentials: .init(
                                provider: .google,
                                idToken: idToken
                            )
                        )
                        
                        guard let authUser = authResponse?.user else {
                            continuation.resume(returning: nil)
                            return
                        }
                        
                        let vnxUser = User(
                            id: authUser.id,
                            email: email,
                            name: name,
                            role: nil
                        )
                        
                        continuation.resume(returning: vnxUser)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("Warning: GoogleService-Info.plist not found or invalid")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }
}

enum AuthError: LocalizedError {
    case invalidCredentials
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid Google Sign-In credentials"
        }
    }
}