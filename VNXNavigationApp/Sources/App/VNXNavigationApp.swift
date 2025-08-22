import SwiftUI
import Supabase

@main
struct VNXNavigationApp: App {
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var navigationService = NavigationService.shared
    @StateObject private var nearbyInteractionService = NearbyInteractionService.shared
    
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
                    if user.role == .anchor {
                        AnchorView()
                    } else {
                        TaggerView()
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