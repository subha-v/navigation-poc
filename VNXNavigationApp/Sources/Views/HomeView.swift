import SwiftUI

struct HomeView: View {
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        Group {
            if let user = authService.currentUser {
                switch user.role {
                case .anchor:
                    AnchorView()
                case .navigator:
                    NavigatorView()
                case .none:
                    RoleSelectionView()
                }
            } else {
                LoadingView()
            }
        }
    }
}

struct RoleSelectionView: View {
    @StateObject private var authService = AuthService.shared
    @State private var selectedRole: UserRole?
    @State private var isUpdating = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text("Select Your Role")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Choose how you want to use the app")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                VStack(spacing: 20) {
                    RoleButton(
                        role: .anchor,
                        icon: "anchor",
                        title: "Anchor",
                        description: "Fixed device that helps others navigate",
                        isSelected: selectedRole == .anchor,
                        action: { selectedRole = .anchor }
                    )
                    
                    RoleButton(
                        role: .navigator,
                        icon: "location.fill",
                        title: "Navigator",
                        description: "Mobile device seeking navigation assistance",
                        isSelected: selectedRole == .navigator,
                        action: { selectedRole = .navigator }
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button(action: updateRole) {
                    if isUpdating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Continue")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(selectedRole != nil ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(selectedRole == nil || isUpdating)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }
    
    private func updateRole() {
        guard let role = selectedRole else { return }
        // In a real app, you'd update this in Firebase
        // For now, we'll just update the local user
        if let user = authService.currentUser {
            authService.currentUser = User(
                id: user.id,
                email: user.email,
                fullName: user.fullName,
                role: role,
                createdAt: user.createdAt
            )
        }
    }
}

struct RoleButton: View {
    let role: UserRole
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top)
        }
    }
}