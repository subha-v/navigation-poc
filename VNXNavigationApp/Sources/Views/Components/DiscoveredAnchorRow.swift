import SwiftUI
import MultipeerConnectivity

struct DiscoveredAnchorRow: View {
    let anchor: DiscoveredAnchor
    let isConnected: Bool
    let onConnect: () -> Void
    let onTap: () -> Void
    
    var body: some View {
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
                
                if isConnected {
                    Text("✓ Connected")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
            
            connectionButton
        }
        .padding()
        .background(
            isConnected ?
            Color.green.opacity(0.1) :
            Color.gray.opacity(0.1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isConnected ?
                    Color.green.opacity(0.3) :
                    Color.clear,
                    lineWidth: 2
                )
        )
        .cornerRadius(10)
        .onTapGesture {
            if isConnected {
                onTap()
            }
        }
    }
    
    @ViewBuilder
    private var connectionButton: some View {
        if isConnected {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else if anchor.isConnecting {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.8)
        } else {
            Button(action: onConnect) {
                Text("Connect")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}