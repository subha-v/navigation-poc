import SwiftUI
import FirebaseCore

@main
struct VNXNavigationApp: App {
    @StateObject private var authService = AuthService.shared
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        if authService.isAuthenticated {
            HomeView()
        } else {
            LoginView()
        }
    }
}