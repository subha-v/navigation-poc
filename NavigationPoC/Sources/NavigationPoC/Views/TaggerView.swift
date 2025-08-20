import SwiftUI

struct TaggerView: View {
    @StateObject private var navigationService = NavigationService.shared
    @State private var selectedDestination: Location?
    @State private var showNavigation = false
    
    let floorPlan = FloorPlan.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "location.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.blue)
                
                Text("Select Destination")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .padding()
            
            // Destination grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 15) {
                    ForEach(floorPlan.destinations) { destination in
                        DestinationCard(
                            destination: destination,
                            isSelected: selectedDestination?.id == destination.id,
                            action: { selectDestination(destination) }
                        )
                    }
                }
                .padding()
            }
            
            // Navigate button
            if selectedDestination != nil {
                Button(action: startNavigation) {
                    HStack {
                        Image(systemName: "location.north.fill")
                        Text("Start Navigation")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.green, Color.teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(15)
                }
                .padding(.horizontal)
                .navigationDestination(isPresented: $showNavigation) {
                    NavigationView(destination: selectedDestination!)
                }
            }
        }
        .navigationTitle("Navigator")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func selectDestination(_ destination: Location) {
        selectedDestination = destination
    }
    
    private func startNavigation() {
        guard selectedDestination != nil else { return }
        showNavigation = true
    }
}

struct DestinationCard: View {
    let destination: Location
    let isSelected: Bool
    let action: () -> Void
    
    var iconName: String {
        switch destination.id {
        case "kitchen": return "cup.and.saucer.fill"
        case "entrance": return "door.left.hand.open"
        case "conference_room": return "person.3.fill"
        case "beanbag": return "chair.lounge.fill"
        default: return "mappin.circle.fill"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(destination.name)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                
                Text("(\(String(format: "%.1f", destination.position.x)), \(String(format: "%.1f", destination.position.y)))")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}