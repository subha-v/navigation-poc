import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "lock.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Forgot Password?")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Enter your email and we'll send you a link to reset your password")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textContentType(.emailAddress)
                .padding(.horizontal, 32)
                .padding(.top, 32)
            
            Button(action: handleResetPassword) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Send Reset Link")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .disabled(isLoading || email.isEmpty)
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Text("Back to Sign In")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            .padding(.bottom, 32)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }
            }
        }
        .alert("Password Reset", isPresented: $showAlert) {
            Button("OK", role: .cancel) {
                if alertMessage.contains("sent") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func handleResetPassword() {
        guard !email.isEmpty else { return }
        
        isLoading = true
        
        Task {
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Password reset functionality will be implemented with your backend"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = "An error occurred"
                    showAlert = true
                }
            }
        }
    }
}