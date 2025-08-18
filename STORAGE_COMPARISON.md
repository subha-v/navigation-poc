# SwiftData vs CoreData for Navigation App

## Quick Answer: Use SwiftData 🎯

## Comparison Table

| Feature | SwiftData | CoreData |
|---------|-----------|----------|
| **Setup Complexity** | ✅ Simple (10 lines) | ❌ Complex (50+ lines) |
| **iOS Version** | iOS 17+ | iOS 10+ |
| **SwiftUI Integration** | ✅ Native | ⚠️ Via @FetchRequest |
| **Type Safety** | ✅ Full Swift types | ❌ NSManagedObject |
| **Migrations** | ✅ Automatic | ⚠️ Manual |
| **CloudKit Sync** | ✅ Built-in | ✅ Mature |
| **Performance** | ✅ Optimized | ✅ Battle-tested |
| **Learning Curve** | ✅ Easy | ❌ Steep |

## For Your Navigation App

### What You're Storing:
- Anchor positions (< 10 items)
- Navigation history (< 1000 sessions)
- User preferences (single object)
- Map cache (file-based, not DB)

### Why SwiftData Wins:

**1. Simpler Code**
```swift
// SwiftData
@Model
class Anchor {
    var id: String
    var position: CGPoint
}

// CoreData (needs .xcdatamodel file + NSManagedObject)
class Anchor: NSManagedObject {
    @NSManaged var id: String?
    @NSManaged var x: Double
    @NSManaged var y: Double
}
```

**2. Better SwiftUI Integration**
```swift
// SwiftData
@Query var anchors: [Anchor]

// CoreData
@FetchRequest(sortDescriptors: []) 
var anchors: FetchedResults<Anchor>
```

**3. Automatic Migrations**
- SwiftData: Just add new properties
- CoreData: Create migration mapping

## When to Use CoreData Instead

Only if you need:
- iOS < 17 support
- Complex relationships (many-to-many)
- Existing CoreData investment
- NSPersistentCloudKitContainer (mature sync)

## Implementation in Your App

I've added `NavigationStorage.swift` with:
- ✅ Anchor storage
- ✅ Navigation history
- ✅ User preferences
- ✅ Analytics
- ✅ Automatic persistence

Just import and use:
```swift
@StateObject var storage = NavigationStorageManager()

// Save anchor
storage.saveAnchor(StoredAnchor(id: "A", x: 10, y: 20))

// Get history
let recent = storage.getRecentSessions()

// Update preferences
storage.updatePreferences { prefs in
    prefs.voiceGuidanceEnabled = true
}
```

## Migration Path

If you start with SwiftData and need CoreData later:
1. Export data to JSON
2. Import into CoreData
3. Keep same model structure

But honestly, SwiftData will handle everything you need for indoor navigation!