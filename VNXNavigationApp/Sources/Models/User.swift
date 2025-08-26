import Foundation

enum UserRole: String, Codable, CaseIterable {
    case anchor = "anchor"
    case tagger = "tagger"
    
    var displayName: String {
        switch self {
        case .anchor:
            return "Anchor (Fixed Position)"
        case .tagger:
            return "Navigator (Mobile User)"
        }
    }
}

struct User: Codable, Identifiable {
    let id: UUID
    let email: String
    var name: String?
    var role: UserRole?  // Optional for Google Sign-In flow
    var anchorLocation: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case role
        case anchorLocation = "anchor_location"
        case createdAt = "created_at"
    }
    
    init(id: UUID = UUID(), email: String, name: String? = nil, role: UserRole? = nil, anchorLocation: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.email = email
        self.name = name
        self.role = role
        self.anchorLocation = anchorLocation
        self.createdAt = createdAt
    }
}