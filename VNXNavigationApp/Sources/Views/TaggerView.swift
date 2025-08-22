import SwiftUI

struct TaggerView: View {
    @EnvironmentObject var navigationService: NavigationService
    @EnvironmentObject var nearbyInteractionService: NearbyInteractionService
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Navigator Mode")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Find and navigate to anchor phones")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Status display
            StatusDisplayView()
            
            // Navigation display
            if nearbyInteractionService.connectionState == .connected {
                NavigationDisplayView()
            }
            
            Spacer()
            
            // Control button
            Button(action: toggleNavigation) {
                Text(navigationService.isNavigating ? "Stop Navigation" : "Start Navigation")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(navigationService.isNavigating ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .navigationTitle("Navigator")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(nearbyInteractionService.$direction) { direction in
            navigationService.updateArrowRotation(from: direction)
        }
    }
    
    private func toggleNavigation() {
        if navigationService.isNavigating {
            navigationService.stopNavigation()
        } else {
            navigationService.startNavigation()
        }
    }
}

struct StatusDisplayView: View {
    @EnvironmentObject var nearbyInteractionService: NearbyInteractionService
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if nearbyInteractionService.connectionState == .disconnected && 
               nearbyInteractionService.isRunning {
                Text("Anchor phone not available")
                    .font(.headline)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var statusColor: Color {
        switch nearbyInteractionService.connectionState {
        case .connected:
            return .green
        case .searching:
            return .orange
        case .disconnected:
            return .red
        }
    }
    
    private var statusText: String {
        switch nearbyInteractionService.connectionState {
        case .connected:
            return "Connected to anchor"
        case .searching:
            return "Searching for anchor phones..."
        case .disconnected:
            return nearbyInteractionService.isRunning ? "No anchor found" : "Not searching"
        }
    }
}

struct NavigationDisplayView: View {
    @EnvironmentObject var navigationService: NavigationService
    @EnvironmentObject var nearbyInteractionService: NearbyInteractionService
    
    var body: some View {
        VStack(spacing: 20) {
            // Arrow indicator
            Image(systemName: "location.north.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .rotationEffect(Angle(degrees: navigationService.arrowRotation))
                .animation(.easeInOut(duration: 0.3), value: navigationService.arrowRotation)
            
            // Distance display
            if let distance = nearbyInteractionService.distance {
                VStack(spacing: 5) {
                    Text(String(format: "%.1f", distance))
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Text("meters")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("to anchor phone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Calculating distance...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Connected anchor info
            if let anchorName = nearbyInteractionService.connectedPeers.first?.displayName {
                Text("Anchor: \(anchorName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(15)
    }
}