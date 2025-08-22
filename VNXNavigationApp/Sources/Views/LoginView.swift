import SwiftUI

struct LoginView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var selectedRole: UserRole = .tagger
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("VALUENEX Navigation")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Indoor Navigation System")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if isSignUp {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(UserRole.allCases, id: \.self) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .padding(.horizontal)
            
            Button(action: authenticate) {
                if supabaseService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(isSignUp ? "Sign Up" : "Sign In")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            .disabled(supabaseService.isLoading)
            
            Button(action: { isSignUp.toggle() }) {
                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(supabaseService.errorMessage ?? "An error occurred")
        }
        .onChange(of: supabaseService.errorMessage) { error in
            showError = error != nil
        }
    }
    
    private func authenticate() {
        Task {
            do {
                if isSignUp {
                    try await supabaseService.signUp(
                        email: email,
                        password: password,
                        role: selectedRole
                    )
                } else {
                    try await supabaseService.signIn(
                        email: email,
                        password: password
                    )
                }
            } catch {
                supabaseService.errorMessage = error.localizedDescription
            }
        }
    }
}