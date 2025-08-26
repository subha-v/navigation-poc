import SwiftUI

struct HomeView: View {
    @StateObject private var authService = AuthService.shared
    @State private var showSignOutAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: roleIcon)
                    .font(.system(size: 100))
                    .foregroundColor(.blue)
                
                Text("Welcome!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let user = authService.currentUser {
                    VStack(spacing: 12) {
                        Text("Successfully signed in as")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(user.role?.displayName ?? "Unknown Role")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        if let fullName = user.fullName, !fullName.isEmpty {
                            Text(fullName)
                                .font(.title3)
                                .fontWeight(.medium)
                        }
                        
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
                }
                
                Spacer()
                
                Button(action: { showSignOutAlert = true }) {
                    Text("Sign Out")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
            .navigationBarHidden(true)
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    handleSignOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    private var roleIcon: String {
        switch authService.currentUser?.role {
        case .anchor:
            return "anchor"
        case .navigator:
            return "location.fill"
        default:
            return "person.circle.fill"
        }
    }
    
    private func handleSignOut() {
        do {
            try authService.signOut()
        } catch {
            print("Error signing out: \(error)")
        }
    }
}