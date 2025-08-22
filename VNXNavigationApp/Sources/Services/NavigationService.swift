import Foundation
import CoreLocation
import SwiftUI
import simd

@MainActor
class NavigationService: ObservableObject {
    static let shared = NavigationService()
    
    @Published var isNavigating = false
    @Published var arrowRotation: Double = 0
    
    private let nearbyInteractionService = NearbyInteractionService.shared
    
    private init() {}
    
    func startNavigation() {
        isNavigating = true
        nearbyInteractionService.startSession()
    }
    
    func stopNavigation() {
        isNavigating = false
        nearbyInteractionService.stopSession()
    }
    
    func updateArrowRotation(from direction: simd_float3?) {
        guard let direction = direction else {
            arrowRotation = 0
            return
        }
        
        // Convert 3D direction vector to 2D rotation angle
        // Using x and z components for horizontal plane rotation
        let angle = atan2(Double(direction.x), Double(direction.z))
        
        // Convert to degrees and adjust for UI
        // Negative because SwiftUI rotation is clockwise
        arrowRotation = -angle * 180 / Double.pi
    }
}