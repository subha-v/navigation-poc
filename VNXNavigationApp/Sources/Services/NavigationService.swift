import Foundation
import CoreLocation
import SwiftUI

@MainActor
class NavigationService: ObservableObject {
    static let shared = NavigationService()
    
    @Published var currentLocation: CGPoint = .zero
    @Published var targetLocation: CGPoint?
    @Published var navigationPath: [CGPoint] = []
    @Published var isNavigating = false
    @Published var distanceToTarget: Double = 0
    @Published var arrowRotation: Double = 0
    
    private init() {}
    
    func startNavigation(to destination: CGPoint) {
        targetLocation = destination
        isNavigating = true
        updateNavigation()
    }
    
    func stopNavigation() {
        targetLocation = nil
        isNavigating = false
        navigationPath = []
    }
    
    func updateCurrentLocation(_ location: CGPoint) {
        currentLocation = location
        if isNavigating {
            updateNavigation()
        }
    }
    
    private func updateNavigation() {
        guard let target = targetLocation else { return }
        
        // Calculate distance
        let dx = target.x - currentLocation.x
        let dy = target.y - currentLocation.y
        distanceToTarget = sqrt(dx * dx + dy * dy)
        
        // Calculate arrow rotation (in radians)
        arrowRotation = atan2(dy, dx)
        
        // Check if arrived (within 0.5 meters)
        if distanceToTarget < 0.5 {
            stopNavigation()
        }
    }
}