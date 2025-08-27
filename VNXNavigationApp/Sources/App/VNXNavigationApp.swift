import SwiftUI
import FirebaseCore

@main
struct VNXNavigationApp: App {
    @StateObject private var authService = AuthService.shared
    private let networkAuth = LocalNetworkAuthorization()
    
    init() {
        FirebaseApp.configure()
        
        // Request local network permission on app launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [networkAuth] in
            networkAuth.requestAuthorization { granted in
                print("🌐 Local Network Permission: \(granted ? "Granted ✅" : "Denied ❌")")
            }
        }
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