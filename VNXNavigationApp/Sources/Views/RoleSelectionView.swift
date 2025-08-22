import SwiftUI

struct RoleSelectionView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Select Your Role")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Choose how you want to use the navigation system")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 20) {
                RoleButton(
                    role: .anchor,
                    icon: "location.circle.fill",
                    description: "Fixed position device that helps others navigate"
                )
                
                RoleButton(
                    role: .tagger,
                    icon: "figure.walk",
                    description: "Mobile device that navigates through the space"
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
            Button("Sign Out") {
                Task {
                    await supabaseService.signOut()
                }
            }
            .foregroundColor(.red)
        }
        .padding()
    }
}

struct RoleButton: View {
    let role: UserRole
    let icon: String
    let description: String
    @EnvironmentObject var supabaseService: SupabaseService
    
    var body: some View {
        Button(action: selectRole) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .frame(width: 60)
                
                VStack(alignment: .leading) {
                    Text(role.displayName)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func selectRole() {
        Task {
            supabaseService.currentUser?.role = role
        }
    }
}