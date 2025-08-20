import Foundation
import CoreGraphics
import simd

class CoordinateTransformService {
    
    // Perform trilateration to calculate position from anchor measurements
    func calculatePosition(from anchors: [NearbyInteractionService.AnchorConnection]) -> CGPoint? {
        guard anchors.count >= 3 else { return nil }
        
        // Use the first 3 anchors with valid distances
        let validAnchors = anchors.filter { $0.distance != nil }.prefix(3)
        guard validAnchors.count >= 3 else { return nil }
        
        let a1 = Array(validAnchors)[0]
        let a2 = Array(validAnchors)[1]
        let a3 = Array(validAnchors)[2]
        
        guard let r1 = a1.distance,
              let r2 = a2.distance,
              let r3 = a3.distance else { return nil }
        
        // Trilateration algorithm
        let p1 = a1.location.position
        let p2 = a2.location.position
        let p3 = a3.location.position
        
        // Convert to double for calculation
        let x1 = Double(p1.x), y1 = Double(p1.y)
        let x2 = Double(p2.x), y2 = Double(p2.y)
        let x3 = Double(p3.x), y3 = Double(p3.y)
        
        let r1d = Double(r1), r2d = Double(r2), r3d = Double(r3)
        
        // Calculate position using trilateration formulas
        let A = 2 * x2 - 2 * x1
        let B = 2 * y2 - 2 * y1
        let C = pow(r1d, 2) - pow(r2d, 2) - pow(x1, 2) + pow(x2, 2) - pow(y1, 2) + pow(y2, 2)
        
        let D = 2 * x3 - 2 * x2
        let E = 2 * y3 - 2 * y2
        let F = pow(r2d, 2) - pow(r3d, 2) - pow(x2, 2) + pow(x3, 2) - pow(y2, 2) + pow(y3, 2)
        
        let denominator = A * E - B * D
        
        // Check for degenerate case (anchors are collinear)
        guard abs(denominator) > 0.001 else {
            print("Anchors are collinear, cannot perform trilateration")
            return nil
        }
        
        let x = (C * E - F * B) / denominator
        let y = (A * F - D * C) / denominator
        
        return CGPoint(x: x, y: y)
    }
    
    // Convert NI distance and direction to relative position
    func relativePosition(distance: Float, direction: simd_float3?) -> CGPoint {
        guard let dir = direction else {
            // If no direction, assume straight ahead
            return CGPoint(x: Double(distance), y: 0)
        }
        
        // Project 3D direction onto 2D plane
        let x = Double(dir.x * distance)
        let y = Double(dir.z * distance) // Using z as forward/back
        
        return CGPoint(x: x, y: y)
    }
    
    // Apply Kalman filter for position smoothing
    func smoothPosition(current: CGPoint, previous: CGPoint?, alpha: Double = 0.3) -> CGPoint {
        guard let prev = previous else { return current }
        
        // Exponential moving average
        let x = prev.x + alpha * (current.x - prev.x)
        let y = prev.y + alpha * (current.y - prev.y)
        
        return CGPoint(x: x, y: y)
    }
    
    // Calculate bearing from one point to another
    func bearing(from: CGPoint, to: CGPoint) -> Double {
        let dx = to.x - from.x
        let dy = to.y - from.y
        return atan2(dy, dx)
    }
    
    // Calculate distance between two points
    func distance(from: CGPoint, to: CGPoint) -> Double {
        let dx = to.x - from.x
        let dy = to.y - from.y
        return sqrt(dx * dx + dy * dy)
    }
    
    // Check if position is within office bounds
    func isValidPosition(_ position: CGPoint) -> Bool {
        let floorPlan = FloorPlan.shared
        return position.x >= 0 && position.x <= floorPlan.officeWidth &&
               position.y >= 0 && position.y <= floorPlan.officeHeight
    }
    
    // Constrain position to office bounds
    func constrainToBounds(_ position: CGPoint) -> CGPoint {
        let floorPlan = FloorPlan.shared
        let x = max(0, min(floorPlan.officeWidth, position.x))
        let y = max(0, min(floorPlan.officeHeight, position.y))
        return CGPoint(x: x, y: y)
    }
}