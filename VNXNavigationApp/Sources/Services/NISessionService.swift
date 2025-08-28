import Foundation
import NearbyInteraction
import MultipeerConnectivity
import Combine
import AVFoundation

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
    @Published var horizontalAngle: Float?  // iOS 16+ property
    @Published var verticalEstimate: String = "Unknown"  // iOS 16+ property
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
                NSLog("❌ Nearby Interaction is not supported on this device")
                NSLog("   - Device may lack U1 chip (need iPhone 11+)")
                NSLog("   - Or UWB may be disabled in your region")
                connectionState = "NI not supported on this device"
                return
            }
            
            NSLog("✅ Device Capabilities:")
            NSLog("   - Precise Distance: \(NISession.deviceCapabilities.supportsPreciseDistanceMeasurement)")
            NSLog("   - Direction: \(NISession.deviceCapabilities.supportsDirectionMeasurement)")
            NSLog("   - Camera Assistance: \(NISession.deviceCapabilities.supportsCameraAssistance)")
        } else {
            guard NISession.isSupported else {
                NSLog("❌ Nearby Interaction is not supported on this device")
                NSLog("   - Device may lack U1 chip (need iPhone 11+)")
                NSLog("   - Or UWB may be disabled in your region")
                connectionState = "NI not supported on this device"
                return
            }
            NSLog("✅ Nearby Interaction is supported (iOS 15 or below)")
        }
        
        NSLog("IMPORTANT: Check these settings on BOTH devices:")
        NSLog("   1. Settings → Privacy → Location Services → System Services → Networking & Wireless = ON")
        NSLog("   2. Settings → Privacy → Nearby Interactions → VNXNavigationApp = Allow")
        NSLog("   3. Settings → Bluetooth = ON")
        NSLog("   4. Settings → Privacy → Local Network → VNXNavigationApp = ON")
        NSLog("   5. Settings → Privacy → Camera → VNXNavigationApp = Allow (for direction)")
    }
    
    func startSession(for peerID: MCPeerID) -> Data? {
        guard NISession.isSupported else {
            NSLog("❌ Cannot start NI session - not supported")
            return nil
        }
        
        niSession = NISession()
        niSession?.delegate = self
        
        guard let token = niSession?.discoveryToken else {
            NSLog("❌ Failed to generate discovery token")
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
            NSLog("📍 Generated NI token: \(preview)")
        }
        
        return tokenData
    }
    
    func receivePeerToken(_ tokenData: Data, from peerID: MCPeerID) {
        guard let token = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NIDiscoveryToken.self,
            from: tokenData
        ) else {
            NSLog("❌ Failed to decode peer token")
            return
        }
        
        peerDiscoveryToken = token
        let tokenString = tokenData.base64EncodedString()
        let preview = String(tokenString.prefix(20)) + "..."
        
        DispatchQueue.main.async {
            self.peerToken = preview
            self.connectionState = "Tokens exchanged, starting ranging"
        }
        
        NSLog("📍 Received peer token from \(peerID.displayName): \(preview)")
        NSLog("   Token is from ANCHOR device: \(peerID.displayName.contains("anchor"))")
        NSLog("DEBUG: My NISession exists: \(niSession != nil)")
        NSLog("DEBUG: About to start ranging with peer's token")
        
        // Check anchor's capabilities if possible
        NSLog("🔍 ANALYZING PEER TOKEN:")
        NSLog("   - Token data size: \(tokenData.count) bytes")
        NSLog("   - My device role: \(peerID.displayName.contains("nav") ? "NAVIGATOR" : "ANCHOR")")
        NSLog("   - Peer device role: \(peerID.displayName.contains("anchor") ? "ANCHOR" : "NAVIGATOR")")
        
        startRanging(with: token)
    }
    
    private func startRanging(with peerToken: NIDiscoveryToken) {
        guard let session = niSession else {
            NSLog("❌ No NI session available")
            return
        }
        
        // Check camera permission status
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        NSLog("\n📷 CAMERA PERMISSION CHECK:")
        switch cameraAuthStatus {
        case .authorized:
            NSLog("   ✅ Camera AUTHORIZED")
        case .denied:
            NSLog("   ❌ Camera DENIED - Direction will NOT work!")
            NSLog("   Go to Settings > Privacy > Camera > VNXNavigationApp")
        case .restricted:
            NSLog("   ❌ Camera RESTRICTED")
        case .notDetermined:
            NSLog("   ⚠️ Camera permission NOT DETERMINED")
            // Request permission
            AVCaptureDevice.requestAccess(for: .video) { granted in
                NSLog("   Camera permission granted: \(granted)")
            }
        @unknown default:
            NSLog("   Unknown camera status")
        }
        
        let config = NINearbyPeerConfiguration(peerToken: peerToken)
        
        // Enable camera assistance if available (following NearbyInteractionDemo approach)
        if #available(iOS 16.0, *) {
            let capabilities = NISession.deviceCapabilities
            NSLog("\n📱 DEVICE CAPABILITIES CHECK:")
            NSLog("   - Supports Camera Assistance: \(capabilities.supportsCameraAssistance)")
            NSLog("   - Supports Direction: \(capabilities.supportsDirectionMeasurement)")
            NSLog("   - Supports Precise Distance: \(capabilities.supportsPreciseDistanceMeasurement)")
            
            if capabilities.supportsCameraAssistance && cameraAuthStatus == .authorized {
                config.isCameraAssistanceEnabled = true
                NSLog("   ✅ Camera assistance ENABLED for direction")
            } else if !capabilities.supportsCameraAssistance {
                NSLog("   ❌ Device does NOT support camera assistance")
            } else if cameraAuthStatus != .authorized {
                NSLog("   ❌ Camera assistance DISABLED (no permission)")
            }
        } else {
            NSLog("   ⚠️ iOS 15 or below - camera assistance experimental")
        }
        
        NSLog("\nDEBUG: Starting NI session")
        NSLog("   Session exists: \(session)")
        NSLog("   Session delegate set: \(session.delegate != nil)")
        NSLog("   My token exists: \(myDiscoveryToken != nil)")
        NSLog("   Peer token exists: \(peerDiscoveryToken != nil)")
        NSLog("   Camera assistance enabled: \(config.isCameraAssistanceEnabled)")
        
        // Save configuration for re-running after suspension
        currentConfiguration = config
        
        session.run(config)
        
        // Check if session is actually running
        NSLog("DEBUG: Called session.run(config)")
        
        DispatchQueue.main.async {
            self.isRunning = true
            self.connectionState = "Ranging active"
        }
        
        NSLog("DEBUG: NI session.run() called successfully")
        NSLog("Started NI ranging with peer")
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
            self.horizontalAngle = nil
            self.verticalEstimate = "Unknown"
            self.isRunning = false
            self.myToken = "Not generated"
            self.peerToken = "Not received"
            self.connectionState = "Not connected"
        }
        
        NSLog("🛑 Stopped NI session")
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
        NSLog("DELEGATE: NI session didUpdate called with \(nearbyObjects.count) objects")
        guard let object = nearbyObjects.first else { 
            NSLog("DELEGATE: No nearby objects in update")
            return 
        }
        
        NSLog("DELEGATE: Object has distance: \(object.distance != nil)")
        NSLog("DELEGATE: Object has direction: \(object.direction != nil)")
        
        // Check for horizontalAngle and verticalDirectionEstimate (iOS 16+)
        if #available(iOS 16.0, *) {
            if let horizontalAngle = object.horizontalAngle {
                let degrees = horizontalAngle * 180 / .pi
                NSLog("DELEGATE: horizontalAngle available: \(horizontalAngle) rad (\(degrees)°)")
                DispatchQueue.main.async {
                    self.horizontalAngle = horizontalAngle
                }
            } else {
                NSLog("DELEGATE: horizontalAngle: nil")
                DispatchQueue.main.async {
                    self.horizontalAngle = nil
                }
            }
            
            let verticalEstimateStr: String
            switch object.verticalDirectionEstimate {
            case .above:
                NSLog("DELEGATE: verticalDirectionEstimate: ABOVE")
                verticalEstimateStr = "Above ↑"
            case .below:
                NSLog("DELEGATE: verticalDirectionEstimate: BELOW")
                verticalEstimateStr = "Below ↓"
            case .same:
                NSLog("DELEGATE: verticalDirectionEstimate: SAME level")
                verticalEstimateStr = "Same Level →"
            case .unknown:
                NSLog("DELEGATE: verticalDirectionEstimate: UNKNOWN")
                verticalEstimateStr = "Unknown"
            case .outOfFieldOfView:
                NSLog("DELEGATE: verticalDirectionEstimate: OUT OF FIELD OF VIEW")
                verticalEstimateStr = "Out of View"
            @unknown default:
                NSLog("DELEGATE: verticalDirectionEstimate: unhandled case")
                verticalEstimateStr = "Unhandled"
            }
            
            DispatchQueue.main.async {
                self.verticalEstimate = verticalEstimateStr
            }
        }
        
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
                
                NSLog("MEASUREMENT: Distance: \(self.formatDistance()), Direction: \(self.formatDirection())")
                NSLog("   Direction vector: x=\(direction.x), y=\(direction.y), z=\(direction.z)")
            } else if object.distance != nil {
                NSLog("MEASUREMENT: Distance: \(self.formatDistance()) (no direction yet)")
                NSLog("   TIP: Point camera at peer and move device to enable direction")
            } else {
                NSLog("MEASUREMENT: No distance or direction available yet")
            }
        }
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        DispatchQueue.main.async {
            self.distance = nil
            self.direction = nil
            self.connectionState = "Peer lost: \(reason)"
        }
        
        NSLog("❌ Lost peer: \(reason)")
    }
    
    func sessionWasSuspended(_ session: NISession) {
        DispatchQueue.main.async {
            self.isRunning = false
            self.connectionState = "Session suspended"
        }
        NSLog("⏸️ NI session suspended")
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        DispatchQueue.main.async {
            self.isRunning = true
            self.connectionState = "Session resumed"
        }
        
        // Re-run configuration after suspension (following NearbyInteractionDemo approach)
        if let config = currentConfiguration {
            session.run(config)
            NSLog("▶️ NI session resumed - re-running configuration")
        } else {
            NSLog("▶️ NI session resumed - no configuration to re-run")
        }
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        NSLog("ERROR: NI session invalidated with error: \(error)")
        NSLog("ERROR: Error localized: \(error.localizedDescription)")
        
        if let nsError = error as NSError? {
            NSLog("ERROR: Error code: \(nsError.code)")
            NSLog("ERROR: Error domain: \(nsError.domain)")
        }
        
        DispatchQueue.main.async {
            self.isRunning = false
            self.connectionState = "Session error: \(error.localizedDescription)"
        }
    }
}