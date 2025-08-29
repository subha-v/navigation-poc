import SwiftUI

struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Arrow pointing up by default
        // Start from the tip
        path.move(to: CGPoint(x: width * 0.5, y: 0))
        
        // Right side of arrow head
        path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.35))
        
        // Right side of arrow shaft
        path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.35))
        
        // Bottom right of shaft
        path.addLine(to: CGPoint(x: width * 0.6, y: height))
        
        // Bottom left of shaft
        path.addLine(to: CGPoint(x: width * 0.4, y: height))
        
        // Left side of arrow shaft
        path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.35))
        
        // Left side of arrow head
        path.addLine(to: CGPoint(x: width * 0.25, y: height * 0.35))
        
        // Close the path back to the tip
        path.closeSubpath()
        
        return path
    }
}

struct ArrowIndicatorView: View {
    let state: DistanceDirectionState
    let azimuth: Float?
    let distance: Float?
    
    @State private var isAnimating = false
    
    private var arrowColor: Color {
        switch state {
        case .closeUpInFOV:
            return .green
        case .notCloseUpInFOV:
            return .blue
        case .outOfFOV:
            return .orange
        case .unknown:
            return .gray
        }
    }
    
    private var arrowOpacity: Double {
        switch state {
        case .closeUpInFOV, .notCloseUpInFOV:
            return 1.0
        case .outOfFOV:
            return 0.6
        case .unknown:
            return 0.3
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Arrow indicator
            ZStack {
                // Background circle for better visibility
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                // Arrow shape
                ArrowShape()
                    .fill(arrowColor)
                    .frame(width: 80, height: 80)
                    .rotationEffect(.radians(Double(azimuth ?? 0)))
                    .opacity(arrowOpacity)
                    .animation(.easeInOut(duration: 0.3), value: azimuth)
                    .scaleEffect(state == .closeUpInFOV && isAnimating ? 1.1 : 1.0)
                    .animation(
                        state == .closeUpInFOV ? 
                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true) : 
                        .default,
                        value: isAnimating
                    )
                
                // Show distance in the center if available
                if let distance = distance, state != .unknown {
                    Text(String(format: "%.1fm", distance))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(arrowColor)
                        .cornerRadius(8)
                        .offset(y: 45)
                }
            }
            .frame(width: 140, height: 140)
            
            // State label
            Text(stateDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .onAppear {
            isAnimating = true
        }
    }
    
    private var stateDescription: String {
        switch state {
        case .closeUpInFOV:
            return "Close to anchor"
        case .notCloseUpInFOV:
            return "Anchor in view"
        case .outOfFOV:
            return "Anchor out of view"
        case .unknown:
            return "Searching for anchor..."
        }
    }
}