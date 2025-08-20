import SwiftUI

struct AnchorView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @StateObject private var niService = NearbyInteractionService.shared
    @State private var selectedLocation: Location?
    @State private var isSharing = false
    
    let floorPlan = FloorPlan.shared
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(isSharing ? .green : .gray)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isSharing)
                
                Text("Anchor Mode")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            
            // Location selection
            if !isSharing {
                VStack(spacing: 20) {
                    Text("Select your anchor position:")
                        .font(.headline)
                    
                    ForEach(floorPlan.anchorLocations) { location in
                        Button(action: { selectLocation(location) }) {
                            HStack {
                                Image(systemName: selectedLocation?.id == location.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text(location.name)
                                        .font(.headline)
                                    Text(location.description)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Text("(\(String(format: "%.2f", location.position.x)), \(String(format: "%.2f", location.position.y)))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedLocation?.id == location.id ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                            )
                        }
                    }
                    
                    Button(action: startSharing) {
                        Text("Start Sharing Location")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(selectedLocation == nil)
                }
                .padding()
            } else {
                // Sharing status
                VStack(spacing: 30) {
                    Text("You are sharing your location")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let location = selectedLocation {
                        VStack(spacing: 10) {
                            Text(location.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            
                            Text(location.description)
                                .font(.body)
                                .foregroundColor(.gray)
                            
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                Text("Position: (\(String(format: "%.2f", location.position.x))m, \(String(format: "%.2f", location.position.y))m)")
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.green.opacity(0.1))
                        )
                    }
                    
                    // Status indicators
                    VStack(spacing: 15) {
                        HStack {
                            Image(systemName: "wifi")
                            Text("Broadcasting UWB Signal")
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Image(systemName: "battery.100")
                            Text("Power Optimized")
                            Spacer()
                            Text("Active")
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    Button(action: stopSharing) {
                        Text("Stop Sharing")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .navigationTitle("Anchor")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            if isSharing {
                niService.stopSession()
            }
        }
    }
    
    private func selectLocation(_ location: Location) {
        selectedLocation = location
    }
    
    private func startSharing() {
        guard let location = selectedLocation else { return }
        
        // Save anchor location to profile
        Task {
            try? await supabaseService.assignAnchorLocation(location.id)
        }
        
        // Start NI anchor mode
        niService.startAnchorMode(at: location)
        isSharing = true
    }
    
    private func stopSharing() {
        niService.stopSession()
        isSharing = false
    }
}