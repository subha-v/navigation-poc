//
//  NavigationManager.swift
//  Main navigation orchestrator
//

import Foundation
import SwiftUI
import Combine

struct NavigationInstruction {
    let text: String
    let icon: String
}

class NavigationManager: ObservableObject {
    // UI State
    @Published var isLocalized = false
    @Published var isNavigating = false
    @Published var currentPosition: CGPoint = .zero
    @Published var currentHeading: Double = 0.0
    @Published var trackingQuality = "Not Tracking"
    @Published var currentPath: [CGPoint]?
    @Published var distanceToDestination: Double?
    @Published var currentInstruction: NavigationInstruction?
    @Published var showAnchorPicker = false
    
    // Map and navigation components
    var mapData: MapData?
    private var localizationManager: LocalizationManager
    private var pathPlanner: AStar?
    private var destination: POI?
    
    // Update timer
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.localizationManager = LocalizationManager()
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind localization updates
        localizationManager.$currentPosition
            .assign(to: &$currentPosition)
        
        localizationManager.$currentHeading
            .assign(to: &$currentHeading)
        
        localizationManager.$isLocalized
            .assign(to: &$isLocalized)
        
        localizationManager.$trackingQuality
            .assign(to: &$trackingQuality)
        
        // Update navigation when position changes
        localizationManager.$currentPosition
            .sink { [weak self] _ in
                self?.updateNavigation()
            }
            .store(in: &cancellables)
    }
    
    func loadMap() {
        // Load map from bundle or documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                          in: .userDomainMask).first else {
            print("Failed to get documents directory")
            return
        }
        
        let mapPath = documentsPath.appendingPathComponent("output_map")
        
        // Check if map exists in documents, otherwise use bundle
        if !FileManager.default.fileExists(atPath: mapPath.path) {
            // For testing, use a default map path
            print("Map not found at \(mapPath)")
            // You would copy from bundle here in production
            return
        }
        
        do {
            mapData = try MapData(mapDirectory: mapPath)
            localizationManager.setMapData(mapData!)
            pathPlanner = AStar(mapData: mapData!)
            localizationManager.startLocalization()
            print("Map loaded successfully")
        } catch {
            print("Failed to load map: \(error)")
        }
    }
    
    func initializeAtAnchor(_ anchor: Anchor) {
        localizationManager.initializeAtAnchor(anchor.id)
    }
    
    func startNavigation(to destination: POI) {
        guard isLocalized, let planner = pathPlanner else {
            print("Cannot navigate: not localized or no map")
            return
        }
        
        self.destination = destination
        
        // Plan path
        if let path = planner.findPath(from: currentPosition, to: destination.position) {
            // Smooth the path
            currentPath = planner.smoothPath(path, epsilon: 0.5)
            isNavigating = true
            
            print("Navigation started to \(destination.name)")
            print("Path has \(currentPath!.count) waypoints")
            
            // Start navigation updates
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                self.updateNavigation()
            }
        } else {
            print("No path found to destination")
        }
    }
    
    func stopNavigation() {
        isNavigating = false
        currentPath = nil
        destination = nil
        distanceToDestination = nil
        currentInstruction = nil
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func updateNavigation() {
        guard isNavigating,
              let path = currentPath,
              let dest = destination else { return }
        
        // Calculate distance to destination
        distanceToDestination = hypot(currentPosition.x - dest.position.x,
                                     currentPosition.y - dest.position.y)
        
        // Check if arrived
        if distanceToDestination! < 2.0 {  // Within 2 meters
            currentInstruction = NavigationInstruction(
                text: "You have arrived at \(dest.name)",
                icon: "checkmark.circle.fill"
            )
            
            // Stop after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.stopNavigation()
            }
            return
        }
        
        // Find closest point on path
        var closestIndex = 0
        var closestDistance = Double.infinity
        
        for (index, waypoint) in path.enumerated() {
            let dist = hypot(currentPosition.x - waypoint.x,
                           currentPosition.y - waypoint.y)
            if dist < closestDistance {
                closestDistance = dist
                closestIndex = index
            }
        }
        
        // Get next waypoint
        let nextIndex = min(closestIndex + 1, path.count - 1)
        if nextIndex < path.count {
            let nextWaypoint = path[nextIndex]
            
            // Calculate turn direction
            let dx = nextWaypoint.x - currentPosition.x
            let dy = nextWaypoint.y - currentPosition.y
            let targetHeading = atan2(dy, dx)
            
            var turnAngle = targetHeading - currentHeading
            // Normalize to [-π, π]
            while turnAngle > .pi { turnAngle -= 2 * .pi }
            while turnAngle < -.pi { turnAngle += 2 * .pi }
            
            // Generate instruction
            if abs(turnAngle) < 0.3 {  // ~17 degrees
                currentInstruction = NavigationInstruction(
                    text: "Continue straight",
                    icon: "arrow.up"
                )
            } else if turnAngle > 0 {
                if turnAngle > 1.0 {  // ~57 degrees
                    currentInstruction = NavigationInstruction(
                        text: "Turn right",
                        icon: "arrow.turn.up.right"
                    )
                } else {
                    currentInstruction = NavigationInstruction(
                        text: "Bear right",
                        icon: "arrow.right"
                    )
                }
            } else {
                if turnAngle < -1.0 {
                    currentInstruction = NavigationInstruction(
                        text: "Turn left",
                        icon: "arrow.turn.up.left"
                    )
                } else {
                    currentInstruction = NavigationInstruction(
                        text: "Bear left",
                        icon: "arrow.left"
                    )
                }
            }
        }
    }
}