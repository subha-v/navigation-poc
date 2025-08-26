import Foundation

struct User: Identifiable, Codable {
    let id: String
    let email: String
    let fullName: String?
    let role: UserRole?
    let createdAt: Date
    
    init(id: String = UUID().uuidString, email: String, fullName: String? = nil, role: UserRole? = nil, createdAt: Date = Date()) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.role = role
        self.createdAt = createdAt
    }
}

enum UserRole: String, CaseIterable, Codable {
    case anchor = "anchor"
    case navigator = "navigator"
    
    var displayName: String {
        switch self {
        case .anchor:
            return "Anchor"
        case .navigator:
            return "Navigator"
        }
    }
}