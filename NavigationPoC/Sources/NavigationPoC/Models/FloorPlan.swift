import Foundation
import CoreGraphics

// Office locations from office_locations_updated.json
struct Location: Codable, Identifiable {
    let id: String
    let name: String
    let position: CGPoint
    let description: String
    
    init(id: String, name: String, x: Double, y: Double, description: String = "") {
        self.id = id
        self.name = name
        self.position = CGPoint(x: x, y: y)
        self.description = description
    }
}

class FloorPlan {
    static let shared = FloorPlan()
    
    // Fixed anchor positions from office_locations_updated.json
    let anchorLocations: [Location] = [
        Location(id: "kitchen", name: "Kitchen", x: 2.73, y: 1.2, description: "Kitchen sink area"),
        Location(id: "entrance", name: "Entrance", x: 3.56, y: 22.18, description: "Main entrance"),
        Location(id: "side_table", name: "Side Table", x: 4.62, y: 17.37, description: "Side table area")
    ]
    
    // All navigable destinations
    let destinations: [Location] = [
        Location(id: "kitchen", name: "Kitchen", x: 2.73, y: 1.2),
        Location(id: "entrance", name: "Entrance", x: 3.56, y: 22.18),
        Location(id: "side_table", name: "Side Table", x: 4.62, y: 17.37),
        Location(id: "conference_room", name: "Conference Room", x: 4.02, y: 9.04),
        Location(id: "david_desk", name: "David's Desk", x: 1.81, y: 4.33),
        Location(id: "taide_desk", name: "Taide's Desk", x: 3.79, y: 4.26),
        Location(id: "beanbag", name: "Beanbag Area", x: 5.17, y: 11.59),
        Location(id: "front_table", name: "Front Table", x: 0.78, y: 22.69),
        Location(id: "hallway_upper", name: "Upper Hallway", x: 2.85, y: 5.0),
        Location(id: "hallway_lower", name: "Lower Hallway", x: 2.85, y: 18.0)
    ]
    
    // Office dimensions
    let officeWidth: Double = 5.71  // meters
    let officeHeight: Double = 23.19 // meters
    let resolution: Double = 0.005   // 5mm per pixel
    
    private init() {}
    
    func getAnchorLocation(byId id: String) -> Location? {
        return anchorLocations.first { $0.id == id }
    }
    
    func getDestination(byId id: String) -> Location? {
        return destinations.first { $0.id == id }
    }
    
    func getDestination(byName name: String) -> Location? {
        return destinations.first { $0.name == name }
    }
}