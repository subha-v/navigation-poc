import Foundation
import CoreGraphics

struct NavigationPath: Codable {
    let waypoints: [CGPoint]
    let totalDistance: Double
    let estimatedTime: Double // seconds
    
    var currentWaypointIndex: Int = 0
    
    mutating func advanceToNextWaypoint() {
        if currentWaypointIndex < waypoints.count - 1 {
            currentWaypointIndex += 1
        }
    }
    
    var currentWaypoint: CGPoint? {
        guard currentWaypointIndex < waypoints.count else { return nil }
        return waypoints[currentWaypointIndex]
    }
    
    var nextWaypoint: CGPoint? {
        let nextIndex = currentWaypointIndex + 1
        guard nextIndex < waypoints.count else { return nil }
        return waypoints[nextIndex]
    }
    
    var isComplete: Bool {
        return currentWaypointIndex >= waypoints.count - 1
    }
    
    func distanceToWaypoint(from position: CGPoint, waypointIndex: Int) -> Double {
        guard waypointIndex < waypoints.count else { return Double.infinity }
        let waypoint = waypoints[waypointIndex]
        let dx = waypoint.x - position.x
        let dy = waypoint.y - position.y
        return sqrt(dx * dx + dy * dy)
    }
}

struct NavigationUpdate {
    let currentPosition: CGPoint
    let distanceToDestination: Double
    let bearingToNextWaypoint: Double // radians
    let confidence: Double // 0.0 to 1.0
    let activeAnchors: Int
}