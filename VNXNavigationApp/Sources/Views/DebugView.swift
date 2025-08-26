import SwiftUI
import NearbyInteraction

struct DebugView: View {
    @EnvironmentObject var nearbyInteractionService: NearbyInteractionService
    @EnvironmentObject var navigationService: NavigationService
    @State private var showTokenDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🔍 DEBUG INFORMATION")
                .font(.headline)
                .foregroundColor(.white)
            
            Divider()
                .background(Color.white)
            
            // Connection Info
            Group {
                Label("Mode", systemImage: "person.fill")
                Text(nearbyInteractionService.isAnchorMode ? "ANCHOR" : "NAVIGATOR")
                    .font(.caption)
                    .foregroundColor(.yellow)
                
                Label("Service Type", systemImage: "network")
                Text("vnxnav-service")
                    .font(.caption)
                
                Label("Peer ID", systemImage: "iphone")
                Text(nearbyInteractionService.peerID?.displayName ?? "Not initialized")
                    .font(.caption)
                    .foregroundColor(nearbyInteractionService.peerID != nil ? .green : .red)
                
                Label("Permission Status", systemImage: "checkmark.shield")
                Text(navigationService.permissionStatus)
                    .font(.caption)
                    .foregroundColor(navigationService.permissionStatus.contains("supported") ? .green : .orange)
            }
            
            Divider()
                .background(Color.white)
            
            // State Info
            Group {
                Label("Connection State", systemImage: "link")
                Text(stateDescription)
                    .font(.caption)
                    .foregroundColor(stateColor)
                
                Label("Is Running", systemImage: "play.circle")
                Text(nearbyInteractionService.isRunning ? "YES" : "NO")
                    .font(.caption)
                    .foregroundColor(nearbyInteractionService.isRunning ? .green : .red)
                
                Label("Connected Peers", systemImage: "person.2")
                Text("\(nearbyInteractionService.connectedPeers.count)")
                    .font(.caption)
            }
            
            Divider()
                .background(Color.white)
            
            // Discovery Token Info
            Group {
                Label("Discovery Token", systemImage: "key.fill")
                if let token = nearbyInteractionService.myDiscoveryToken {
                    Button(action: { showTokenDetails.toggle() }) {
                        Text(showTokenDetails ? tokenDescription(token) : "Tap to show")
                            .font(.caption2)
                            .foregroundColor(.cyan)
                            .lineLimit(showTokenDetails ? nil : 1)
                    }
                } else {
                    Text("Not generated")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Divider()
                .background(Color.white)
            
            // UWB Data (when connected)
            if nearbyInteractionService.connectionState == .connected {
                Group {
                    Label("Distance", systemImage: "ruler")
                    if let distance = nearbyInteractionService.distance {
                        Text(String(format: "%.2f meters", distance))
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Measuring...")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Label("Direction", systemImage: "location.north.fill")
                    if let direction = nearbyInteractionService.direction {
                        VStack(alignment: .leading) {
                            Text("X: \(String(format: "%.3f", direction.x))")
                            Text("Y: \(String(format: "%.3f", direction.y))")
                            Text("Z: \(String(format: "%.3f", direction.z))")
                        }
                        .font(.caption2)
                        .foregroundColor(.green)
                    } else {
                        Text("Calculating...")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Peer Tokens
            if !nearbyInteractionService.peerTokens.isEmpty {
                Divider()
                    .background(Color.white)
                
                Label("Peer Tokens", systemImage: "key.horizontal")
                ForEach(Array(nearbyInteractionService.peerTokens.keys), id: \.self) { peer in
                    Text("• \(peer.displayName)")
                        .font(.caption2)
                        .foregroundColor(.cyan)
                }
            }
            
            // Timestamps
            Divider()
                .background(Color.white)
            
            Text("Last Update: \(Date(), formatter: timeFormatter)")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.green, lineWidth: 1)
        )
    }
    
    private var stateDescription: String {
        switch nearbyInteractionService.connectionState {
        case .disconnected: return "DISCONNECTED"
        case .searching: return "SEARCHING..."
        case .connected: return "CONNECTED"
        }
    }
    
    private var stateColor: Color {
        switch nearbyInteractionService.connectionState {
        case .disconnected: return .red
        case .searching: return .orange
        case .connected: return .green
        }
    }
    
    private func tokenDescription(_ token: NIDiscoveryToken) -> String {
        let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        let size = data?.count ?? 0
        let preview = data?.prefix(20).map { String(format: "%02x", $0) }.joined() ?? "N/A"
        return "Size: \(size) bytes\nPreview: \(preview)..."
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }
}