import SwiftUI
import Supabase
import NearbyInteraction

@main
struct VNXNavigationApp: App {
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var navigationService = NavigationService.shared
    @StateObject private var nearbyInteractionService = NearbyInteractionService.shared
    
    init() {
        // Check Nearby Interaction support
        if NISession.isSupported {
            print("✅ Device supports Nearby Interaction")
        } else {
            print("❌ Device does NOT support Nearby Interaction")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(supabaseService)
                .environmentObject(navigationService)
                .environmentObject(nearbyInteractionService)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    
    var body: some View {
        NavigationView {
            if supabaseService.isAuthenticated {
                if let user = supabaseService.currentUser {
                    if let role = user.role {
                        // User has selected a role
                        if role == .anchor {
                            AnchorView()
                        } else {
                            TaggerView()
                        }
                    } else {
                        // User needs to select a role
                        RoleSelectionView()
                    }
                } else {
                    RoleSelectionView()
                }
            } else {
                LoginView()
            }
        }
    }
}