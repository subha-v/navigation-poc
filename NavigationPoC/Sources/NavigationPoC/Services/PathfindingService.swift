import Foundation
import Alamofire
import CoreGraphics
import Combine

class PathfindingService: ObservableObject {
    static let shared = PathfindingService()
    
    @Published var currentPath: NavigationPath?
    @Published var isCalculating = false
    @Published var errorMessage: String?
    
    // Python server configuration (update ServerConfig.swift with your IP)
    private let serverURL = ServerConfig.serverURL
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // Request path from Python A* server
    func requestPath(from start: CGPoint, to destination: Location) async throws -> NavigationPath {
        isCalculating = true
        errorMessage = nil
        
        let parameters: [String: Any] = [
            "start": [
                "x": start.x,
                "y": start.y
            ],
            "goal": [
                "x": destination.position.x,
                "y": destination.position.y
            ]
        ]
        
        do {
            let response = try await AF.request("\(serverURL)/api/find_path",
                                               method: .post,
                                               parameters: parameters,
                                               encoding: JSONEncoding.default)
                .serializingDecodable(PathResponse.self)
                .value
            
            guard response.success else {
                throw PathfindingError.noPathFound(response.error ?? "Unknown error")
            }
            
            let waypoints = response.path.map { CGPoint(x: $0[0], y: $0[1]) }
            let path = NavigationPath(
                waypoints: waypoints,
                totalDistance: response.distance,
                estimatedTime: response.distance / 1.2 // Assuming 1.2 m/s walking speed
            )
            
            DispatchQueue.main.async {
                self.currentPath = path
                self.isCalculating = false
            }
            
            return path
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isCalculating = false
            }
            throw error
        }
    }
    
    // Register anchor with server
    func registerAnchor(id: String, position: CGPoint) async throws {
        let parameters: [String: Any] = [
            "id": id,
            "x": position.x,
            "y": position.y,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        _ = try await AF.request("\(serverURL)/api/anchors/register",
                                 method: .post,
                                 parameters: parameters,
                                 encoding: JSONEncoding.default)
            .serializingData()
            .value
    }
    
    // Get active anchors from server
    func getActiveAnchors() async throws -> [AnchorStatus] {
        let response = try await AF.request("\(serverURL)/api/anchors/status")
            .serializingDecodable([AnchorStatus].self)
            .value
        
        return response
    }
    
    // Update position for real-time path recalculation
    func updatePosition(_ position: CGPoint) {
        guard var path = currentPath,
              !path.isComplete else { return }
        
        // Check if we've reached the current waypoint
        if let currentWaypoint = path.currentWaypoint {
            let distance = sqrt(pow(position.x - currentWaypoint.x, 2) + 
                              pow(position.y - currentWaypoint.y, 2))
            
            if distance < 0.5 { // Within 50cm of waypoint
                path.advanceToNextWaypoint()
                DispatchQueue.main.async {
                    self.currentPath = path
                }
            }
        }
        
        // Check if we're too far off path (>2m)
        if let nearestWaypoint = path.currentWaypoint {
            let distance = sqrt(pow(position.x - nearestWaypoint.x, 2) + 
                              pow(position.y - nearestWaypoint.y, 2))
            
            if distance > 2.0 {
                // Request path recalculation
                Task {
                    if let destination = FloorPlan.shared.destinations.first(where: { 
                        $0.position == path.waypoints.last 
                    }) {
                        _ = try? await requestPath(from: position, to: destination)
                    }
                }
            }
        }
    }
}

// MARK: - Response Models

struct PathResponse: Codable {
    let success: Bool
    let path: [[Double]]
    let distance: Double
    let waypoints: Int
    let error: String?
}

struct AnchorStatus: Codable {
    let id: String
    let x: Double
    let y: Double
    let active: Bool
    let lastSeen: TimeInterval
    
    var position: CGPoint {
        CGPoint(x: x, y: y)
    }
}

// MARK: - Errors

enum PathfindingError: LocalizedError {
    case noPathFound(String)
    case serverUnavailable
    case invalidPosition
    
    var errorDescription: String? {
        switch self {
        case .noPathFound(let reason):
            return "No path found: \(reason)"
        case .serverUnavailable:
            return "Navigation server is unavailable"
        case .invalidPosition:
            return "Invalid position for navigation"
        }
    }
}