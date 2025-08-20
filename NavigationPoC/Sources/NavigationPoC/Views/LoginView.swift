import SwiftUI

struct LoginView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var selectedRole: UserRole = .tagger
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Logo
                Image(systemName: "location.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                
                Text("VALUENEX Navigation")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Form
                VStack(spacing: 20) {
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
                
                // Action buttons
                VStack(spacing: 15) {
                    Button(action: handleSubmit) {
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
                    .disabled(supabaseService.isLoading || email.isEmpty || password.isEmpty)
                    
                    Button(action: { isSignUp.toggle() }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(supabaseService.errorMessage ?? "An error occurred")
            }
        }
    }
    
    private func handleSubmit() {
        Task {
            do {
                if isSignUp {
                    try await supabaseService.signUp(email: email, password: password, role: selectedRole)
                } else {
                    try await supabaseService.signIn(email: email, password: password)
                }
            } catch {
                showError = true
            }
        }
    }
}