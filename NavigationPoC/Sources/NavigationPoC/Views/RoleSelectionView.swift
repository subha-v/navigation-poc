import SwiftUI

struct RoleSelectionView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var navigateToAnchor = false
    @State private var navigateToTagger = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text("Welcome, \(supabaseService.currentUser?.email ?? "User")")
                    .font(.title2)
                    .padding()
                
                Text("Select Mode")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Role selection based on user's registered role
                if let user = supabaseService.currentUser {
                    if user.role == .anchor {
                        AnchorModeButton()
                            .navigationDestination(isPresented: $navigateToAnchor) {
                                AnchorView()
                            }
                    } else {
                        TaggerModeButton()
                            .navigationDestination(isPresented: $navigateToTagger) {
                                TaggerView()
                            }
                    }
                } else {
                    // Show both options if no user role is set
                    VStack(spacing: 20) {
                        AnchorModeButton()
                            .navigationDestination(isPresented: $navigateToAnchor) {
                                AnchorView()
                            }
                        
                        TaggerModeButton()
                            .navigationDestination(isPresented: $navigateToTagger) {
                                TaggerView()
                            }
                    }
                }
                
                Spacer()
                
                Button(action: signOut) {
                    Text("Sign Out")
                        .foregroundColor(.red)
                }
                .padding()
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
    
    private func signOut() {
        Task {
            await supabaseService.signOut()
        }
    }
}

struct AnchorModeButton: View {
    var body: some View {
        NavigationLink(destination: AnchorView()) {
            VStack(spacing: 15) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.white)
                
                Text("Anchor Mode")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Share your fixed position")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(30)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
        }
    }
}

struct TaggerModeButton: View {
    var body: some View {
        NavigationLink(destination: TaggerView()) {
            VStack(spacing: 15) {
                Image(systemName: "location.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.white)
                
                Text("Navigator Mode")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Navigate to destinations")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(30)
            .background(
                LinearGradient(
                    colors: [Color.green, Color.teal],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
        }
    }
}