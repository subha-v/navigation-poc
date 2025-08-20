import Foundation
import CoreGraphics
import CoreMotion
import Combine

class NavigationService: ObservableObject {
    static let shared = NavigationService()
    
    @Published var isNavigating = false
    @Published var currentDestination: Location?
    @Published var navigationUpdate: NavigationUpdate?
    @Published var hasArrived = false
    @Published var arrowDirection: Double = 0.0 // Radians
    @Published var distanceToDestination: String = "--"
    @Published var navigationStatus: String = "Ready"
    
    private let niService = NearbyInteractionService.shared
    private let pathfindingService = PathfindingService.shared
    private let motionManager = CMMotionManager()
    private let coordinateTransform = CoordinateTransformService()
    
    private var cancellables = Set<AnyCancellable>()
    private var deviceHeading: Double = 0.0
    private var lastPosition: CGPoint?
    private var arrivalThreshold: Double = 1.0 // 1 meter
    
    private init() {
        setupSubscriptions()
        setupMotionUpdates()
    }
    
    private func setupSubscriptions() {
        // Subscribe to position updates from NI service
        niService.$currentPosition
            .compactMap { $0 }
            .sink { [weak self] position in
                self?.handlePositionUpdate(position)
            }
            .store(in: &cancellables)
        
        // Subscribe to path updates
        pathfindingService.$currentPath
            .compactMap { $0 }
            .sink { [weak self] path in
                self?.handlePathUpdate(path)
            }
            .store(in: &cancellables)
    }
    
    private func setupMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion else { return }
            
            // Get device heading (yaw)
            self?.deviceHeading = motion.attitude.yaw
        }
    }
    
    // MARK: - Public Methods
    
    func startNavigation(to destination: Location) async {
        currentDestination = destination
        isNavigating = true
        hasArrived = false
        navigationStatus = "Calculating route..."
        
        // Start NI tagger mode if not already active
        if !niService.isSessionActive {
            niService.startTaggerMode()
        }
        
        // Wait for position fix
        var attempts = 0
        while niService.currentPosition == nil && attempts < 30 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            attempts += 1
        }
        
        guard let currentPos = niService.currentPosition ?? lastPosition else {
            navigationStatus = "Unable to determine position"
            return
        }
        
        // Request path from server
        do {
            navigationStatus = "Finding path..."
            _ = try await pathfindingService.requestPath(from: currentPos, to: destination)
            navigationStatus = "Navigating to \(destination.name)"
        } catch {
            navigationStatus = "Path calculation failed"
            print("Navigation error: \(error)")
        }
    }
    
    func stopNavigation() {
        isNavigating = false
        currentDestination = nil
        hasArrived = false
        navigationStatus = "Navigation stopped"
        niService.stopSession()
        motionManager.stopDeviceMotionUpdates()
    }
    
    // MARK: - Private Methods
    
    private func handlePositionUpdate(_ position: CGPoint) {
        lastPosition = position
        
        guard isNavigating,
              let destination = currentDestination,
              let path = pathfindingService.currentPath else { return }
        
        // Update pathfinding service with current position
        pathfindingService.updatePosition(position)
        
        // Calculate distance to destination
        let distanceValue = coordinateTransform.distance(from: position, to: destination.position)
        distanceToDestination = String(format: "%.1f m", distanceValue)
        
        // Check if arrived
        if distanceValue < arrivalThreshold {
            handleArrival()
            return
        }
        
        // Calculate arrow direction to next waypoint
        if let nextWaypoint = path.currentWaypoint ?? path.nextWaypoint {
            let bearing = coordinateTransform.bearing(from: position, to: nextWaypoint)
            
            // Adjust for device heading
            arrowDirection = bearing - deviceHeading
            
            // Create navigation update
            let update = NavigationUpdate(
                currentPosition: position,
                distanceToDestination: distanceValue,
                bearingToNextWaypoint: bearing,
                confidence: niService.positionConfidence,
                activeAnchors: niService.connectedAnchors.count
            )
            
            DispatchQueue.main.async {
                self.navigationUpdate = update
            }
        }
    }
    
    private func handlePathUpdate(_ path: NavigationPath) {
        // Path has been updated (initial or recalculated)
        navigationStatus = "Following path (\(path.waypoints.count) waypoints)"
    }
    
    private func handleArrival() {
        guard !hasArrived else { return }
        
        hasArrived = true
        isNavigating = false
        navigationStatus = "You have arrived!"
        distanceToDestination = "0.0 m"
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // MARK: - Arrow Calculation
    
    func getArrowRotation() -> Double {
        // Convert radians to degrees and adjust for SwiftUI rotation
        return arrowDirection * 180 / .pi
    }
    
    func getArrowScale() -> Double {
        // Scale arrow based on confidence
        return 0.5 + (niService.positionConfidence * 0.5)
    }
    
    func getStatusColor() -> String {
        if hasArrived {
            return "green"
        } else if niService.connectedAnchors.count < 3 {
            return "orange"
        } else {
            return "blue"
        }
    }
}