//
//  NavigationStorage.swift
//  SwiftData storage for navigation data
//

import SwiftUI
import SwiftData
import CoreLocation

// MARK: - Data Models

@Model
final class StoredAnchor {
    var id: String
    var x: Double
    var y: Double
    var lastUpdated: Date
    var signalStrength: Int
    
    init(id: String, x: Double, y: Double) {
        self.id = id
        self.x = x
        self.y = y
        self.lastUpdated = Date()
        self.signalStrength = 100
    }
    
    var position: CGPoint {
        CGPoint(x: x, y: y)
    }
}

@Model
final class NavigationHistory {
    var sessionID: UUID
    var startTime: Date
    var endTime: Date?
    var startPoint: String  // JSON encoded CGPoint
    var endPoint: String    // JSON encoded CGPoint
    var pathData: Data      // Encoded path points
    var totalDistance: Double
    var completed: Bool
    
    init(start: CGPoint, end: CGPoint) {
        self.sessionID = UUID()
        self.startTime = Date()
        self.startPoint = "\(start.x),\(start.y)"
        self.endPoint = "\(end.x),\(end.y)"
        self.pathData = Data()
        self.totalDistance = 0
        self.completed = false
    }
}

@Model
final class UserPreferences {
    var preferredMapResolution: Double
    var voiceGuidanceEnabled: Bool
    var hapticFeedbackEnabled: Bool
    var pathColor: String
    var lastUsedAnchorID: String?
    
    init() {
        self.preferredMapResolution = 0.05
        self.voiceGuidanceEnabled = true
        self.hapticFeedbackEnabled = true
        self.pathColor = "blue"
        self.lastUsedAnchorID = nil
    }
}

// MARK: - Storage Manager

@MainActor
class NavigationStorageManager: ObservableObject {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    
    @Published var anchors: [StoredAnchor] = []
    @Published var navigationHistory: [NavigationHistory] = []
    @Published var preferences: UserPreferences?
    
    init() {
        do {
            // Configure model container
            let schema = Schema([
                StoredAnchor.self,
                NavigationHistory.self,
                UserPreferences.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            self.modelContext = modelContainer.mainContext
            
            // Load existing data
            fetchData()
            
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    // MARK: - Anchor Management
    
    func saveAnchor(_ anchor: StoredAnchor) {
        modelContext.insert(anchor)
        save()
        fetchAnchors()
    }
    
    func updateAnchorPosition(id: String, position: CGPoint) {
        if let anchor = anchors.first(where: { $0.id == id }) {
            anchor.x = position.x
            anchor.y = position.y
            anchor.lastUpdated = Date()
            save()
        }
    }
    
    func deleteAnchor(_ anchor: StoredAnchor) {
        modelContext.delete(anchor)
        save()
        fetchAnchors()
    }
    
    // MARK: - Navigation History
    
    func startNavigationSession(from: CGPoint, to: CGPoint) -> NavigationHistory {
        let session = NavigationHistory(start: from, end: to)
        modelContext.insert(session)
        save()
        return session
    }
    
    func completeNavigationSession(_ session: NavigationHistory, path: [CGPoint], distance: Double) {
        session.endTime = Date()
        session.completed = true
        session.totalDistance = distance
        
        // Encode path
        if let encoded = try? JSONEncoder().encode(path.map { [$0.x, $0.y] }) {
            session.pathData = encoded
        }
        
        save()
        fetchHistory()
    }
    
    func getRecentSessions(limit: Int = 10) -> [NavigationHistory] {
        return Array(navigationHistory
            .sorted { $0.startTime > $1.startTime }
            .prefix(limit))
    }
    
    // MARK: - Preferences
    
    func loadOrCreatePreferences() -> UserPreferences {
        if let existing = preferences {
            return existing
        }
        
        let newPrefs = UserPreferences()
        modelContext.insert(newPrefs)
        save()
        self.preferences = newPrefs
        return newPrefs
    }
    
    func updatePreferences(_ block: (UserPreferences) -> Void) {
        let prefs = loadOrCreatePreferences()
        block(prefs)
        save()
    }
    
    // MARK: - Private Methods
    
    private func fetchData() {
        fetchAnchors()
        fetchHistory()
        fetchPreferences()
    }
    
    private func fetchAnchors() {
        do {
            let descriptor = FetchDescriptor<StoredAnchor>(
                sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
            )
            anchors = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch anchors: \(error)")
        }
    }
    
    private func fetchHistory() {
        do {
            let descriptor = FetchDescriptor<NavigationHistory>(
                sortBy: [SortDescriptor(\.startTime, order: .reverse)]
            )
            navigationHistory = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch history: \(error)")
        }
    }
    
    private func fetchPreferences() {
        do {
            let descriptor = FetchDescriptor<UserPreferences>()
            preferences = try modelContext.fetch(descriptor).first
        } catch {
            print("Failed to fetch preferences: \(error)")
        }
    }
    
    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save: \(error)")
        }
    }
    
    // MARK: - Analytics
    
    func getNavigationStats() -> NavigationStats {
        let completed = navigationHistory.filter { $0.completed }.count
        let total = navigationHistory.count
        let totalDistance = navigationHistory
            .filter { $0.completed }
            .reduce(0) { $0 + $1.totalDistance }
        
        let avgDistance = completed > 0 ? totalDistance / Double(completed) : 0
        
        return NavigationStats(
            totalSessions: total,
            completedSessions: completed,
            totalDistance: totalDistance,
            averageDistance: avgDistance,
            successRate: total > 0 ? Double(completed) / Double(total) : 0
        )
    }
}

struct NavigationStats {
    let totalSessions: Int
    let completedSessions: Int
    let totalDistance: Double
    let averageDistance: Double
    let successRate: Double
}

// MARK: - SwiftUI Integration

struct NavigationStorageView: View {
    @StateObject private var storage = NavigationStorageManager()
    
    var body: some View {
        List {
            Section("Stored Anchors") {
                ForEach(storage.anchors) { anchor in
                    HStack {
                        Text(anchor.id)
                        Spacer()
                        Text("(\(String(format: "%.1f", anchor.x)), \(String(format: "%.1f", anchor.y)))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Section("Recent Navigation") {
                ForEach(storage.getRecentSessions(limit: 5)) { session in
                    VStack(alignment: .leading) {
                        Text(session.sessionID.uuidString.prefix(8) + "...")
                            .font(.caption)
                        Text("Distance: \(String(format: "%.1f m", session.totalDistance))")
                        Text(session.completed ? "✓ Completed" : "⚠️ Incomplete")
                            .font(.caption)
                            .foregroundColor(session.completed ? .green : .orange)
                    }
                }
            }
            
            Section("Statistics") {
                let stats = storage.getNavigationStats()
                LabeledContent("Total Sessions", value: "\(stats.totalSessions)")
                LabeledContent("Success Rate", value: "\(Int(stats.successRate * 100))%")
                LabeledContent("Avg Distance", value: "\(String(format: "%.1f m", stats.averageDistance))")
            }
        }
        .navigationTitle("Navigation Data")
    }
}