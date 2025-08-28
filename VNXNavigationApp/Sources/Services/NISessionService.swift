import Foundation
import NearbyInteraction
import MultipeerConnectivity
import Combine

struct TokenExchange: Codable {
    let type: String
    let token: Data
    let peerName: String
    let timestamp: Date
}

class NISessionService: NSObject, ObservableObject {
    @Published var distance: Float?
    @Published var direction: simd_float3?
    @Published var azimuth: Float?
    @Published var elevation: Float?
    @Published var isRunning = false
    @Published var myToken: String = "Not generated"
    @Published var peerToken: String = "Not received"
    @Published var connectionState = "Not connected"
    @Published var coachingMessage = ""
    
    private var niSession: NISession?
    private var myDiscoveryToken: NIDiscoveryToken?
    private var peerDiscoveryToken: NIDiscoveryToken?
    private var currentPeerID: MCPeerID?
    private var currentConfiguration: NINearbyPeerConfiguration?
    
    override init() {
        super.init()
        checkDeviceCapabilities()
    }
    
    private func checkDeviceCapabilities() {
        // Check iOS 16+ for better capability checking
        if #available(iOS 16.0, *) {
            guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
                print("❌ Nearby Interaction is not supported on this device")
                print("   - Device may lack U1 chip (need iPhone 11+)")
                print("   - Or UWB may be disabled in your region")
                connectionState = "NI not supported on this device"
                return
            }
            
            print("✅ Device Capabilities:")
            print("   - Precise Distance: \(NISession.deviceCapabilities.supportsPreciseDistanceMeasurement)")
            print("   - Direction: \(NISession.deviceCapabilities.supportsDirectionMeasurement)")
            print("   - Camera Assistance: \(NISession.deviceCapabilities.supportsCameraAssistance)")
        } else {
            guard NISession.isSupported else {
                print("❌ Nearby Interaction is not supported on this device")
                print("   - Device may lack U1 chip (need iPhone 11+)")
                print("   - Or UWB may be disabled in your region")
                connectionState = "NI not supported on this device"
                return
            }
            print("✅ Nearby Interaction is supported (iOS 15 or below)")
        }
        
        print("IMPORTANT: Check these settings on BOTH devices:")
        print("   1. Settings → Privacy → Location Services → System Services → Networking & Wireless = ON")
        print("   2. Settings → Privacy → Nearby Interactions → VNXNavigationApp = Allow")
        print("   3. Settings → Bluetooth = ON")
        print("   4. Settings → Privacy → Local Network → VNXNavigationApp = ON")
        print("   5. Settings → Privacy → Camera → VNXNavigationApp = Allow (for direction)")
    }
    
    func startSession(for peerID: MCPeerID) -> Data? {
        guard NISession.isSupported else {
            print("❌ Cannot start NI session - not supported")
            return nil
        }
        
        niSession = NISession()
        niSession?.delegate = self
        
        guard let token = niSession?.discoveryToken else {
            print("❌ Failed to generate discovery token")
            return nil
        }
        
        myDiscoveryToken = token
        currentPeerID = peerID
        
        let tokenData = try? NSKeyedArchiver.archivedData(
            withRootObject: token,
            requiringSecureCoding: true
        )
        
        if let data = tokenData {
            let tokenString = data.base64EncodedString()
            let preview = String(tokenString.prefix(20)) + "..."
            DispatchQueue.main.async {
                self.myToken = preview
                self.connectionState = "Token generated, waiting for peer"
            }
            print("📍 Generated NI token: \(preview)")
        }
        
        return tokenData
    }
    
    func receivePeerToken(_ tokenData: Data, from peerID: MCPeerID) {
        guard let token = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NIDiscoveryToken.self,
            from: tokenData
        ) else {
            print("❌ Failed to decode peer token")
            return
        }
        
        peerDiscoveryToken = token
        let tokenString = tokenData.base64EncodedString()
        let preview = String(tokenString.prefix(20)) + "..."
        
        DispatchQueue.main.async {
            self.peerToken = preview
            self.connectionState = "Tokens exchanged, starting ranging"
        }
        
        print("📍 Received peer token from \(peerID.displayName): \(preview)")
        print("DEBUG: My NISession exists: \(niSession != nil)")
        print("DEBUG: About to start ranging with peer's token")
        
        startRanging(with: token)
    }
    
    private func startRanging(with peerToken: NIDiscoveryToken) {
        guard let session = niSession else {
            print("❌ No NI session available")
            return
        }
        
        let config = NINearbyPeerConfiguration(peerToken: peerToken)
        
        // Enable camera assistance if available (following NearbyInteractionDemo approach)
        if #available(iOS 16.0, *) {
            if NISession.deviceCapabilities.supportsCameraAssistance {
                config.isCameraAssistanceEnabled = true
                print("✅ Camera assistance ENABLED for direction measurements")
            } else {
                print("⚠️ Camera assistance NOT supported on this device")
            }
        }
        
        print("DEBUG: About to run NI session")
        print("DEBUG: Session exists: \(session)")
        print("DEBUG: Session delegate is set: \(session.delegate != nil)")
        print("DEBUG: My token exists: \(myDiscoveryToken != nil)")
        print("DEBUG: Peer token received: \(peerDiscoveryToken != nil)")
        print("DEBUG: Camera assistance enabled: \(config.isCameraAssistanceEnabled)")
        
        // Save configuration for re-running after suspension
        currentConfiguration = config
        
        session.run(config)
        
        // Check if session is actually running
        print("DEBUG: Called session.run(config)")
        
        DispatchQueue.main.async {
            self.isRunning = true
            self.connectionState = "Ranging active"
        }
        
        print("DEBUG: NI session.run() called successfully")
        print("Started NI ranging with peer")
    }
    
    func stopSession() {
        niSession?.invalidate()
        niSession = nil
        myDiscoveryToken = nil
        peerDiscoveryToken = nil
        currentPeerID = nil
        currentConfiguration = nil
        
        DispatchQueue.main.async {
            self.distance = nil
            self.direction = nil
            self.azimuth = nil
            self.elevation = nil
            self.isRunning = false
            self.myToken = "Not generated"
            self.peerToken = "Not received"
            self.connectionState = "Not connected"
        }
        
        print("🛑 Stopped NI session")
    }
    
    func formatDistance() -> String {
        guard let distance = distance else { return "-- m" }
        return String(format: "%.2f m", distance)
    }
    
    func formatDirection() -> String {
        guard let azimuth = azimuth, let elevation = elevation else { return "No direction" }
        let azimuthDegrees = azimuth * 180 / .pi
        let elevationDegrees = elevation * 180 / .pi
        return String(format: "Az: %.0f° El: %.0f°", azimuthDegrees, elevationDegrees)
    }
}

extension NISessionService: NISessionDelegate {
    // Algorithm convergence for direction measurements
    func session(_ session: NISession, didUpdateAlgorithmConvergence convergence: NIAlgorithmConvergence, for object: NINearbyObject?) {
        if case .notConverged(let reasons) = convergence.status {
            guard !reasons.isEmpty else { 
                DispatchQueue.main.async {
                    self.coachingMessage = ""
                }
                return 
            }
            
            var message = "For direction measurements:"
            for reason in reasons {
                switch reason {
                case .insufficientSignalStrength:
                    message += "\n• Move devices closer together"
                case .insufficientHorizontalSweep:
                    message += "\n• Sweep device horizontally (left ↔️ right)"
                case .insufficientVerticalSweep:
                    message += "\n• Sweep device vertically (up ↕️ down)"
                case .insufficientMovement:
                    message += "\n• Move device around slowly"
                case .insufficientLighting:
                    message += "\n• Move to a brighter area 💡"
                default:
                    break
                }
            }
            
            DispatchQueue.main.async {
                self.coachingMessage = message
            }
        } else if case .converged = convergence.status {
            DispatchQueue.main.async {
                self.coachingMessage = "✅ Ready - Point camera at peer device"
                // Clear message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if self.coachingMessage.contains("Ready") {
                        self.coachingMessage = ""
                    }
                }
            }
        }
    }
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        print("DELEGATE: NI session didUpdate called with \(nearbyObjects.count) objects")
        guard let object = nearbyObjects.first else { 
            print("DELEGATE: No nearby objects in update")
            return 
        }
        
        print("DELEGATE: Object has distance: \(object.distance != nil)")
        print("DELEGATE: Object has direction: \(object.direction != nil)")
        
        DispatchQueue.main.async {
            self.distance = object.distance
            
            if let direction = object.direction {
                self.direction = direction
                
                // Use the same calculations as NearbyInteractionDemo
                // azimuth: horizontal angle (left/right)
                let azimuth = asin(direction.x)
                // elevation: vertical angle (up/down)
                let elevation = atan2(direction.z, direction.y) + .pi / 2
                
                self.azimuth = azimuth
                self.elevation = elevation
                
                print("MEASUREMENT: Distance: \(self.formatDistance()), Direction: \(self.formatDirection())")
                print("   Direction vector: x=\(direction.x), y=\(direction.y), z=\(direction.z)")
            } else if object.distance != nil {
                print("MEASUREMENT: Distance: \(self.formatDistance()) (no direction yet)")
            } else {
                print("MEASUREMENT: No distance or direction available yet")
            }
        }
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        DispatchQueue.main.async {
            self.distance = nil
            self.direction = nil
            self.connectionState = "Peer lost: \(reason)"
        }
        
        print("❌ Lost peer: \(reason)")
    }
    
    func sessionWasSuspended(_ session: NISession) {
        DispatchQueue.main.async {
            self.isRunning = false
            self.connectionState = "Session suspended"
        }
        print("⏸️ NI session suspended")
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        DispatchQueue.main.async {
            self.isRunning = true
            self.connectionState = "Session resumed"
        }
        
        // Re-run configuration after suspension (following NearbyInteractionDemo approach)
        if let config = currentConfiguration {
            session.run(config)
            print("▶️ NI session resumed - re-running configuration")
        } else {
            print("▶️ NI session resumed - no configuration to re-run")
        }
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        print("ERROR: NI session invalidated with error: \(error)")
        print("ERROR: Error localized: \(error.localizedDescription)")
        
        if let nsError = error as NSError? {
            print("ERROR: Error code: \(nsError.code)")
            print("ERROR: Error domain: \(nsError.domain)")
        }
        
        DispatchQueue.main.async {
            self.isRunning = false
            self.connectionState = "Session error: \(error.localizedDescription)"
        }
    }
}