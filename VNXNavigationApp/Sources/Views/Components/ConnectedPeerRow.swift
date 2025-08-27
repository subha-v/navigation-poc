import SwiftUI
import MultipeerConnectivity

struct ConnectedPeerRow: View {
    let peer: ConnectedPeer
    let isNavigatorWithNI: Bool
    let niSessionService: NISessionService?
    let onPing: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "location.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                peerInfo
                
                if isNavigatorWithNI, let niService = niSessionService {
                    niSessionInfo(niService: niService)
                }
            }
            
            Spacer()
            
            Button(action: onPing) {
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
    
    @ViewBuilder
    private var peerInfo: some View {
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
    
    @ViewBuilder
    private func niSessionInfo(niService: NISessionService) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NI Session Active")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.orange)
            
            Text("My: \(niService.myToken)")
                .font(.caption2)
                .fontWeight(.monospaced)
                .lineLimit(1)
            
            Text("Peer: \(niService.peerToken)")
                .font(.caption2)
                .fontWeight(.monospaced)
                .lineLimit(1)
            
            if niService.isRunning {
                Text("Distance: \(niService.formatDistance())")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
        }
    }
}