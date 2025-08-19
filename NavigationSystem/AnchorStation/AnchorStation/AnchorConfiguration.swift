//
//  AnchorConfiguration.swift
//  Centralized anchor configuration from output_map_1cm
//

import Foundation
import CoreGraphics

struct AnchorData {
    let id: String
    let position: CGPoint
    let displayName: String
}

struct POIData {
    let id: String
    let name: String
    let position: CGPoint
}

class AnchorConfiguration {
    static let shared = AnchorConfiguration()
    
    // Anchor positions from output_map_1cm/anchors.json
    let anchors: [AnchorData] = [
        AnchorData(id: "anchor_A", position: CGPoint(x: -5.0, y: 5.0), displayName: "Anchor A"),
        AnchorData(id: "anchor_B", position: CGPoint(x: 3.0, y: 5.0), displayName: "Anchor B"),
        AnchorData(id: "anchor_C", position: CGPoint(x: -5.0, y: -5.0), displayName: "Anchor C"),
        AnchorData(id: "anchor_D", position: CGPoint(x: 3.0, y: -5.0), displayName: "Anchor D"),
        AnchorData(id: "anchor_E", position: CGPoint(x: -1.0, y: 0.0), displayName: "Anchor E")
    ]
    
    // Points of Interest from output_map_1cm/navigation_config.json
    let pois: [POIData] = [
        POIData(id: "poi_1", name: "Reception", position: CGPoint(x: -8.0, y: 0.0)),
        POIData(id: "poi_2", name: "Conference Room A", position: CGPoint(x: -3.0, y: 3.0)),
        POIData(id: "poi_3", name: "Conference Room B", position: CGPoint(x: 2.0, y: 3.0)),
        POIData(id: "poi_4", name: "AI Healthcare Booth", position: CGPoint(x: -2.0, y: -3.0)),
        POIData(id: "poi_5", name: "Innovation Lab", position: CGPoint(x: 4.0, y: 0.0)),
        POIData(id: "poi_6", name: "Cafeteria", position: CGPoint(x: 0.0, y: -7.0)),
        POIData(id: "poi_7", name: "Demo Area", position: CGPoint(x: -6.0, y: 7.0)),
        POIData(id: "poi_8", name: "VR Experience Zone", position: CGPoint(x: 5.0, y: 7.0))
    ]
    
    // Navigation settings from output_map_1cm/navigation_config.json
    struct NavigationSettings {
        static let minAnchorsForTrilateration = 3
        static let maxAnchorRange: Float = 20.0
        static let positionSmoothingFactor: Float = 0.3
        static let pathSmoothingEpsilon: Float = 0.5
        static let nlosDetectionThreshold: Float = 2.0
    }
    
    // Map metadata
    struct MapMetadata {
        static let resolution: Double = 0.01  // 1cm
        static let origin = CGPoint(x: -10.183403122754692, y: -10.85751695737398)
        static let widthPx = 1793
        static let heightPx = 2118
        static let boundsMin = CGPoint(x: -10.183403122754692, y: -10.85751695737398)
        static let boundsMax = CGPoint(x: 7.7386974646492135, y: 10.315749005479974)
    }
    
    private init() {}
    
    func getAnchor(byId id: String) -> AnchorData? {
        return anchors.first { $0.id == id }
    }
    
    func getPOI(byName name: String) -> POIData? {
        return pois.first { $0.name == name }
    }
    
    func getNearestAnchors(to position: CGPoint, count: Int = 3) -> [AnchorData] {
        return anchors.sorted { anchor1, anchor2 in
            let dist1 = distance(from: position, to: anchor1.position)
            let dist2 = distance(from: position, to: anchor2.position)
            return dist1 < dist2
        }.prefix(count).map { $0 }
    }
    
    private func distance(from: CGPoint, to: CGPoint) -> CGFloat {
        let dx = from.x - to.x
        let dy = from.y - to.y
        return sqrt(dx * dx + dy * dy)
    }
}