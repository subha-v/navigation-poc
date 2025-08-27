import SwiftUI
import MultipeerConnectivity

struct AnchorView: View {
    @StateObject private var anchorService = AnchorService.shared
    @StateObject private var authService = AuthService.shared
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                VStack(spacing: 10) {
                    Image(systemName: "anchor")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Anchor Mode")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let user = authService.currentUser {
                        Text("ID: \(user.id.prefix(8))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                VStack(spacing: 15) {
                    HStack {
                        Circle()
                            .fill(anchorService.isAdvertising ? Color.green : Color.gray)
                            .frame(width: 10, height: 10)
                        
                        Text(anchorService.advertisingStatus)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    if !anchorService.isAdvertising {
                        Button(action: startAdvertising) {
                            Label("Start Advertising", systemImage: "antenna.radiowaves.left.and.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal)
                    } else {
                        Button(action: stopAdvertising) {
                            Label("Stop Advertising", systemImage: "stop.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .padding(.horizontal)
                    }
                }
                
                Divider()
                    .padding(.vertical)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Connected Navigators")
                            .font(.headline)
                        
                        Spacer()
                        
                        if !anchorService.connectedPeers.isEmpty {
                            Text("\(anchorService.connectedPeers.count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    if anchorService.connectedPeers.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("No navigators connected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if anchorService.isAdvertising {
                                Text("Waiting for connections...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(anchorService.connectedPeers) { peer in
                                    HStack {
                                        Image(systemName: "location.fill")
                                            .foregroundColor(.blue)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(peer.displayName)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            HStack {
                                                Text("Connected")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                                
                                                if let lastPing = peer.lastPingTime {
                                                    Text("• Last ping: \(lastPing, style: .relative) ago")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            anchorService.sendPing(to: peer.peerID)
                                        }) {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        handleSignOut()
                    }
                    .foregroundColor(.red)
                }
            }
            .alert("Anchor Service", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            if !anchorService.isAdvertising {
                startAdvertising()
            }
        }
        .onDisappear {
            anchorService.cleanup()
        }
    }
    
    private func startAdvertising() {
        guard let user = authService.currentUser else { return }
        anchorService.startAdvertising(anchorID: String(user.id.prefix(8)))
    }
    
    private func stopAdvertising() {
        anchorService.stopAdvertising()
    }
    
    private func handleSignOut() {
        anchorService.cleanup()
        do {
            try authService.signOut()
        } catch {
            alertMessage = "Failed to sign out: \(error.localizedDescription)"
            showAlert = true
        }
    }
}