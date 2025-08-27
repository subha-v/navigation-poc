import SwiftUI
import MultipeerConnectivity

struct NavigatorView: View {
    @StateObject private var navigatorService = NavigatorService.shared
    @StateObject private var authService = AuthService.shared
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showBrowserUI = false
    @State private var selectedAnchor: DiscoveredAnchor?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                VStack(spacing: 10) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Navigator Mode")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let user = authService.currentUser {
                        Text("Navigator: \(user.fullName ?? user.email)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                VStack(spacing: 15) {
                    HStack {
                        Circle()
                            .fill(navigatorService.isBrowsing ? Color.green : Color.gray)
                            .frame(width: 10, height: 10)
                        
                        Text(navigatorService.connectionStatus)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        if !navigatorService.isBrowsing {
                            Button(action: startBrowsing) {
                                Label("Custom Browse", systemImage: "antenna.radiowaves.left.and.right")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        } else {
                            Button(action: stopBrowsing) {
                                Label("Stop", systemImage: "stop.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                        
                        Button(action: { showBrowserUI = true }) {
                            Label("System UI", systemImage: "rectangle.stack.badge.person.crop")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                    .padding(.vertical)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Online Anchors")
                            .font(.headline)
                        
                        Spacer()
                        
                        if !navigatorService.discoveredAnchors.isEmpty {
                            Text("\(navigatorService.discoveredAnchors.count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    if navigatorService.discoveredAnchors.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("No anchors found")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if navigatorService.isBrowsing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                
                                Text("Searching for anchors...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(navigatorService.discoveredAnchors) { anchor in
                                    HStack {
                                        Image(systemName: "anchor")
                                            .foregroundColor(.blue)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(anchor.displayName)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            Text("Anchor ID: \(anchor.anchorID)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            if isConnectedToAnchor(anchor) {
                                                Text("✓ Connected")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if isConnectedToAnchor(anchor) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        } else if anchor.isConnecting {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle())
                                                .scaleEffect(0.8)
                                        } else {
                                            Button(action: {
                                                connectToAnchor(anchor)
                                            }) {
                                                Text("Connect")
                                                    .font(.caption)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.small)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        isConnectedToAnchor(anchor) ?
                                        Color.green.opacity(0.1) :
                                        Color.gray.opacity(0.1)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                isConnectedToAnchor(anchor) ?
                                                Color.green.opacity(0.3) :
                                                Color.clear,
                                                lineWidth: 2
                                            )
                                    )
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
            .alert("Connection Status", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .onChange(of: navigatorService.connectionStatus) { newStatus in
                if newStatus.contains("Connection established") {
                    alertMessage = newStatus
                    showAlert = true
                }
            }
            .sheet(isPresented: $showBrowserUI) {
                MCBrowserView(service: navigatorService)
            }
        }
        .onAppear {
            setupNavigator()
        }
        .onDisappear {
            navigatorService.cleanup()
        }
    }
    
    private func setupNavigator() {
        guard let user = authService.currentUser else { return }
        let navigatorID = user.fullName ?? user.email.components(separatedBy: "@").first ?? "navigator"
        
        // Setup peer but don't start browsing automatically
        // Let user choose between custom browse or system UI
        if navigatorService.peerID == nil {
            navigatorService.setupPeerID(displayName: "nav:\(navigatorID)")
        }
    }
    
    private func startBrowsing() {
        guard let user = authService.currentUser else { return }
        let navigatorID = user.fullName ?? user.email.components(separatedBy: "@").first ?? "navigator"
        navigatorService.startBrowsing(navigatorID: navigatorID)
    }
    
    private func stopBrowsing() {
        navigatorService.stopBrowsing()
    }
    
    private func connectToAnchor(_ anchor: DiscoveredAnchor) {
        navigatorService.connectToAnchor(anchor)
    }
    
    private func isConnectedToAnchor(_ anchor: DiscoveredAnchor) -> Bool {
        navigatorService.connectedPeers.contains { $0.peerID == anchor.peerID }
    }
    
    private func handleSignOut() {
        navigatorService.cleanup()
        do {
            try authService.signOut()
        } catch {
            alertMessage = "Failed to sign out: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// UIKit Bridge for MCBrowserViewController
struct MCBrowserView: UIViewControllerRepresentable {
    let service: NavigatorService
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> MCBrowserViewController {
        guard let peerID = service.peerID,
              let session = service.session else {
            fatalError("PeerID and Session must be initialized")
        }
        
        let browser = MCBrowserViewController(
            serviceType: MultipeerService.serviceType,
            session: session
        )
        browser.delegate = context.coordinator
        browser.minimumNumberOfPeers = 1
        browser.maximumNumberOfPeers = 8
        
        return browser
    }
    
    func updateUIViewController(_ uiViewController: MCBrowserViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MCBrowserViewControllerDelegate {
        let parent: MCBrowserView
        
        init(_ parent: MCBrowserView) {
            self.parent = parent
        }
        
        func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}