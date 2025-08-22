import SwiftUI

struct AnchorView: View {
    @EnvironmentObject var nearbyInteractionService: NearbyInteractionService
    @State private var selectedLocation = "Kitchen"
    
    let anchorLocations = ["Kitchen", "Entrance", "Side Table"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Anchor Mode")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This device is providing location reference")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Location selector
            VStack(alignment: .leading) {
                Text("Anchor Position")
                    .font(.headline)
                
                Picker("Location", selection: $selectedLocation) {
                    ForEach(anchorLocations, id: \.self) { location in
                        Text(location).tag(location)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Status indicator
            HStack {
                Circle()
                    .fill(nearbyInteractionService.isRunning ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(nearbyInteractionService.isRunning ? "Broadcasting" : "Offline")
                    .font(.subheadline)
            }
            
            // Connected devices
            if !nearbyInteractionService.connectedPeers.isEmpty {
                VStack(alignment: .leading) {
                    Text("Connected Devices")
                        .font(.headline)
                    
                    ForEach(nearbyInteractionService.connectedPeers, id: \.self) { peer in
                        Text(peer.displayName)
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            
            Spacer()
            
            // Control button
            Button(action: toggleBroadcast) {
                Text(nearbyInteractionService.isRunning ? "Stop Broadcasting" : "Start Broadcasting")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(nearbyInteractionService.isRunning ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .navigationTitle("Anchor")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func toggleBroadcast() {
        if nearbyInteractionService.isRunning {
            nearbyInteractionService.stopSession()
        } else {
            nearbyInteractionService.startSession()
        }
    }
}