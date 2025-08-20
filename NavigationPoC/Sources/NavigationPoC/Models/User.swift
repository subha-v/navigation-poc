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
    let role: UserRole
    var anchorLocation: String? // For anchor users, which position they're at
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case role
        case anchorLocation = "anchor_location"
        case createdAt = "created_at"
    }
}