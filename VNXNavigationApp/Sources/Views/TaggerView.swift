import SwiftUI

struct TaggerView: View {
    @EnvironmentObject var navigationService: NavigationService
    @EnvironmentObject var nearbyInteractionService: NearbyInteractionService
    @State private var selectedDestination = "Conference Room"
    
    let destinations = [
        "Conference Room",
        "Kitchen",
        "Reception",
        "Meeting Room 1",
        "Meeting Room 2"
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Navigator Mode")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Destination selector
            VStack(alignment: .leading) {
                Text("Select Destination")
                    .font(.headline)
                
                Picker("Destination", selection: $selectedDestination) {
                    ForEach(destinations, id: \.self) { destination in
                        Text(destination).tag(destination)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Navigation display
            if navigationService.isNavigating {
                NavigationDisplayView()
            }
            
            // Distance indicator
            if let distance = nearbyInteractionService.distance {
                Text("Distance to nearest anchor: \(String(format: "%.1f", distance))m")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Start navigation button
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
    }
    
    private func toggleNavigation() {
        if navigationService.isNavigating {
            navigationService.stopNavigation()
            nearbyInteractionService.stopSession()
        } else {
            // Start navigation to selected destination
            // This would normally fetch the destination coordinates from the server
            navigationService.startNavigation(to: CGPoint(x: 5, y: 10))
            nearbyInteractionService.startSession()
        }
    }
}

struct NavigationDisplayView: View {
    @EnvironmentObject var navigationService: NavigationService
    
    var body: some View {
        VStack {
            // Arrow indicator
            Image(systemName: "arrow.up")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .rotationEffect(Angle(radians: navigationService.arrowRotation))
                .animation(.easeInOut(duration: 0.3), value: navigationService.arrowRotation)
            
            // Distance display
            Text("\(String(format: "%.1f", navigationService.distanceToTarget))m")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("to destination")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(15)
    }
}