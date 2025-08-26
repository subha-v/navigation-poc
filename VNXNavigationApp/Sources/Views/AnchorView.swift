import SwiftUI

struct AnchorView: View {
    @EnvironmentObject var nearbyInteractionService: NearbyInteractionService
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Anchor Mode")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Broadcasting location for navigators")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Debug Info
            VStack(alignment: .leading, spacing: 5) {
                Text("DEBUG INFO")
                    .font(.caption)
                    .fontWeight(.bold)
                Text("Mode: ANCHOR")
                    .font(.caption)
                Text("Service: vnxnav-service")
                    .font(.caption)
                Text("PeerID: \(nearbyInteractionService.peerID?.displayName ?? "Not set")")
                    .font(.caption)
                Text("Advertising: \(nearbyInteractionService.isRunning ? "YES" : "NO")")
                    .font(.caption)
                    .foregroundColor(nearbyInteractionService.isRunning ? .green : .red)
            }
            .padding()
            .background(Color.yellow.opacity(0.2))
            .cornerRadius(8)
            
            // Status indicator
            VStack(spacing: 15) {
                // Broadcasting status
                HStack {
                    Circle()
                        .fill(nearbyInteractionService.isRunning ? Color.green : Color.red)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.green.opacity(0.3), lineWidth: 2)
                                .scaleEffect(nearbyInteractionService.isRunning ? 2 : 1)
                                .opacity(nearbyInteractionService.isRunning ? 0 : 1)
                                .animation(
                                    nearbyInteractionService.isRunning ?
                                    Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true) :
                                    .default,
                                    value: nearbyInteractionService.isRunning
                                )
                        )
                    
                    Text(nearbyInteractionService.isRunning ? "Broadcasting" : "Offline")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                // Connection info
                if nearbyInteractionService.isRunning {
                    VStack(spacing: 10) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("\(nearbyInteractionService.connectedPeers.count)")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.blue)
                        
                        Text(nearbyInteractionService.connectedPeers.count == 1 ? "Navigator Connected" : "Navigators Connected")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(15)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Connected devices list
            if !nearbyInteractionService.connectedPeers.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Connected Navigators")
                        .font(.headline)
                    
                    ForEach(nearbyInteractionService.connectedPeers, id: \.self) { peer in
                        HStack {
                            Image(systemName: "iphone")
                                .foregroundColor(.blue)
                            Text(peer.displayName)
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                        .padding(.vertical, 5)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            
            Spacer()
            
            // Control button
            Button(action: toggleBroadcast) {
                HStack {
                    Image(systemName: nearbyInteractionService.isRunning ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                    Text(nearbyInteractionService.isRunning ? "Stop Broadcasting" : "Start Broadcasting")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(nearbyInteractionService.isRunning ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            // Info text
            Text("Keep this screen open while acting as an anchor")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .navigationTitle("Anchor")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func toggleBroadcast() {
        if nearbyInteractionService.isRunning {
            nearbyInteractionService.stopSession()
        } else {
            nearbyInteractionService.startAsAnchor()
        }
    }
}