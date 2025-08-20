import SwiftUI
import Supabase

@main
struct NavigationPoCApp: App {
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var navigationService = NavigationService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(supabaseService)
                .environmentObject(navigationService)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    
    var body: some View {
        if supabaseService.isAuthenticated {
            RoleSelectionView()
        } else {
            LoginView()
        }
    }
}