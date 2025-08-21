import Foundation

// Server Configuration
// Update this with your Mac's IP address when running the Python server
struct ServerConfig {
    // For simulator testing, use localhost
    // For device testing, use your Mac's IP address (e.g., "192.168.1.100")
    static let serverURL = "http://localhost:8080"
    
    // To find your Mac's IP:
    // 1. Open System Preferences > Network
    // 2. Select your WiFi connection
    // 3. Your IP is shown (e.g., 192.168.1.100)
    // 4. Update the serverURL above to: "http://YOUR_IP:8080"
}