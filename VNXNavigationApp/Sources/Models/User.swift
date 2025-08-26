import Foundation

struct User: Identifiable, Codable {
    let id: String
    let email: String
    let fullName: String?
    let createdAt: Date
    
    init(id: String = UUID().uuidString, email: String, fullName: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.createdAt = createdAt
    }
}