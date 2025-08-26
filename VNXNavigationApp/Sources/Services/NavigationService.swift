import Foundation
import CoreLocation
import SwiftUI
import simd
import NearbyInteraction

@MainActor
class NavigationService: ObservableObject {
    static let shared = NavigationService()
    
    @Published var isNavigating = false
    @Published var arrowRotation: Double = 0
    @Published var permissionStatus: String = "Not checked"
    
    private let nearbyInteractionService = NearbyInteractionService.shared
    
    private init() {}
    
    func checkPermissions() {
        // Check if NearbyInteraction is supported
        if NISession.isSupported {
            permissionStatus = "NearbyInteraction supported"
            print("✅ VNXNavigationApp: NearbyInteraction is supported on this device")
        } else {
            permissionStatus = "NearbyInteraction NOT supported"
            print("❌ VNXNavigationApp: NearbyInteraction is NOT supported on this device")
        }
    }
    
    func startNavigation() {
        isNavigating = true
        checkPermissions()
        nearbyInteractionService.startAsNavigator()
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