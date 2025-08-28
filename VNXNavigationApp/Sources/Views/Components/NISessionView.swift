import SwiftUI

struct NISessionView: View {
    let anchor: DiscoveredAnchor
    let niSessionService: NISessionService
    let onStartSession: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            Divider()
            
            Text("NI Session with \(anchor.displayName)")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                tokenRow(label: "My Token:", token: niSessionService.myToken)
                tokenRow(label: "Peer Token:", token: niSessionService.peerToken)
                statusRow
                
                if niSessionService.isRunning {
                    distanceRow
                    directionRow
                }
                
                // Show coaching message if available
                if !niSessionService.coachingMessage.isEmpty {
                    Text(niSessionService.coachingMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 4)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(10)
            
            Button(action: onStartSession) {
                Label("Start NI Session", systemImage: "dot.radiowaves.left.and.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func tokenRow(label: String, token: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(token)
                .font(.system(.caption2, design: .monospaced))
        }
    }
    
    @ViewBuilder
    private var statusRow: some View {
        HStack {
            Text("Status:")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(niSessionService.connectionState)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    @ViewBuilder
    private var distanceRow: some View {
        HStack {
            Text("Distance:")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(niSessionService.formatDistance())
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
        }
    }
    
    @ViewBuilder
    private var directionRow: some View {
        HStack {
            Text("Direction:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if niSessionService.direction != nil {
                Text(niSessionService.formatDirection())
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            } else {
                Text("Point camera at peer")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}