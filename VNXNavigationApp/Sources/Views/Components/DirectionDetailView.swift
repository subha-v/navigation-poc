import SwiftUI

struct DirectionDetailView: View {
    let niSessionService: NISessionService
    let anchorName: String
    
    private var isPointingAtAzimuth: Bool {
        guard let azimuth = niSessionService.azimuth else { return false }
        return abs(azimuth.radiansToDegrees) <= 15
    }
    
    private var isPointingAtElevation: Bool {
        guard let elevation = niSessionService.elevation else { return false }
        return abs(elevation.radiansToDegrees) <= 15
    }
    
    var body: some View {
        VStack(spacing: 15) {
            // Anchor name
            Text(anchorName)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Distance
            HStack {
                Image(systemName: "ruler")
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text("Distance:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(niSessionService.formatDistance())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(distanceColor)
            }
            
            // Only show direction details if we have direction data
            if niSessionService.direction != nil {
                Divider()
                
                // Azimuth (Horizontal angle)
                HStack {
                    // Left arrow
                    Image(systemName: "arrow.left")
                        .foregroundColor(.blue)
                        .opacity(azimuthArrowOpacity(isLeft: true))
                        .frame(width: 20)
                    
                    Text("Horizontal:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let azimuth = niSessionService.azimuth {
                        Text(String(format: "%+.0f°", azimuth.radiansToDegrees))
                            .font(.title3)
                            .fontWeight(isPointingAtAzimuth ? .bold : .medium)
                            .foregroundColor(isPointingAtAzimuth ? .green : .primary)
                    } else {
                        Text("--°")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    
                    // Right arrow
                    Image(systemName: "arrow.right")
                        .foregroundColor(.blue)
                        .opacity(azimuthArrowOpacity(isLeft: false))
                        .frame(width: 20)
                }
                
                // Elevation (Vertical angle)
                HStack {
                    // Direction indicator
                    Image(systemName: elevationArrowIcon)
                        .foregroundColor(.orange)
                        .frame(width: 20)
                    
                    Text("Vertical:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let elevation = niSessionService.elevation {
                        Text(String(format: "%+.0f°", elevation.radiansToDegrees))
                            .font(.title3)
                            .fontWeight(isPointingAtElevation ? .bold : .medium)
                            .foregroundColor(isPointingAtElevation ? .green : .primary)
                    } else {
                        Text("--°")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }
                
                // iOS 16+ vertical estimate
                if #available(iOS 16.0, *) {
                    HStack {
                        Image(systemName: "arrow.up.and.down")
                            .foregroundColor(.purple)
                            .frame(width: 20)
                        
                        Text("Level:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(niSessionService.verticalEstimate)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
                    }
                }
            }
            
            // Coaching message if available
            if !niSessionService.coachingMessage.isEmpty {
                Text(niSessionService.coachingMessage)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.top, 5)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
    }
    
    private var distanceColor: Color {
        guard let distance = niSessionService.distance else { return .gray }
        
        if distance < 0.3 {
            return .green
        } else if distance < 1.0 {
            return .blue
        } else if distance < 3.0 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func azimuthArrowOpacity(isLeft: Bool) -> Double {
        guard let azimuth = niSessionService.azimuth else { return 0.25 }
        
        if isPointingAtAzimuth {
            return 0.25
        }
        
        if isLeft {
            return azimuth < 0 ? 1.0 : 0.25
        } else {
            return azimuth > 0 ? 1.0 : 0.25
        }
    }
    
    private var elevationArrowIcon: String {
        guard let elevation = niSessionService.elevation else { return "arrow.up.and.down" }
        
        if elevation < 0 {
            return "arrow.down"
        } else if elevation > 0 {
            return "arrow.up"
        } else {
            return "arrow.right"
        }
    }
}