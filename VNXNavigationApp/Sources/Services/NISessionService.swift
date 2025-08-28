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
        NSLog("\n========== STARTING NI SESSION ==========")
        NSLog("🔍 DEVICE ROLE: I am \(peerID.displayName)")
        
        // Use new API for iOS 16+, fallback to deprecated for older versions
        if #available(iOS 16.0, *) {
            guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
                NSLog("❌ Cannot start NI session - not supported")
                return nil
            }
        } else {
            guard NISession.isSupported else {
                NSLog("❌ Cannot start NI session - not supported")
                return nil
            }
        }
        
        // Check capabilities BEFORE creating session
        if #available(iOS 16.0, *) {
            NSLog("📱 PRE-SESSION DEVICE CHECK:")
            let caps = NISession.deviceCapabilities
            NSLog("   - Device supports camera assistance: \(caps.supportsCameraAssistance)")
            NSLog("   - Device supports direction: \(caps.supportsDirectionMeasurement)")
            NSLog("   - Device supports precise distance: \(caps.supportsPreciseDistanceMeasurement)")
            
            // Log exact device model
            var systemInfo = utsname()
            uname(&systemInfo)
            let modelCode = withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    ptr in String(validatingUTF8: ptr)
                }
            }
            NSLog("   - Device model code: \(modelCode ?? "Unknown")")
            
            // Check camera permission BEFORE session creation
            let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            NSLog("   - Camera permission status: \(cameraStatus == .authorized ? "✅ AUTHORIZED" : "❌ NOT AUTHORIZED")")
        }
        
        niSession = NISession()
        niSession?.delegate = self
        NSLog("✅ NISession created and delegate set")
        
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
            NSLog("📍 TOKEN GENERATED:")
            NSLog("   - Token preview: \(preview)")
            NSLog("   - Token data size: \(data.count) bytes")
            NSLog("   - My role: \(peerID.displayName.contains("nav") ? "NAVIGATOR" : "ANCHOR")")
        }
        
        NSLog("========== SESSION STARTED ==========\n")
        return tokenData
    }
    
    func receivePeerToken(_ tokenData: Data, from peerID: MCPeerID) {
        NSLog("\n========== RECEIVING PEER TOKEN ==========")
        
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
        
        NSLog("📍 TOKEN EXCHANGE DETAILS:")
        NSLog("   - Received from: \(peerID.displayName)")
        NSLog("   - Token preview: \(preview)")
        NSLog("   - Token data size: \(tokenData.count) bytes")
        
        let myRole = currentPeerID?.displayName.contains("nav") == true ? "NAVIGATOR" : "ANCHOR"
        let peerRole = peerID.displayName.contains("anchor") ? "ANCHOR" : "NAVIGATOR"
        
        NSLog("🎭 ROLE VERIFICATION:")
        NSLog("   - MY role: \(myRole)")
        NSLog("   - PEER role: \(peerRole)")
        NSLog("   - NISession exists: \(niSession != nil)")
        NSLog("   - NISession delegate set: \(niSession?.delegate != nil)")
        
        NSLog("========== END TOKEN EXCHANGE ==========\n")
        
        startRanging(with: token)
    }
    
    private func startRanging(with peerToken: NIDiscoveryToken) {
        NSLog("\n========== STARTING RANGING ==========")
        
        guard let session = niSession else {
            NSLog("❌ CRITICAL: No NI session available - cannot start ranging!")
            return
        }
        
        // Check camera permission status
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        NSLog("📷 CAMERA PERMISSION:")
        switch cameraAuthStatus {
        case .authorized:
            NSLog("   ✅ AUTHORIZED - Direction should work")
        case .denied:
            NSLog("   ❌ DENIED - Direction will NOT work!")
            NSLog("   ACTION REQUIRED: Settings > Privacy > Camera > VNXNavigationApp")
        case .restricted:
            NSLog("   ❌ RESTRICTED - Direction will NOT work!")
        case .notDetermined:
            NSLog("   ⚠️ NOT DETERMINED - Requesting permission...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                NSLog("   Camera permission result: \(granted ? "✅ GRANTED" : "❌ DENIED")")
            }
        @unknown default:
            NSLog("   ⚠️ Unknown camera status")
        }
        
        let config = NINearbyPeerConfiguration(peerToken: peerToken)
        
        // Enable camera assistance if available
        if #available(iOS 16.0, *) {
            let capabilities = NISession.deviceCapabilities
            NSLog("\n🔬 DEVICE CAPABILITY ANALYSIS:")
            NSLog("   - Camera Assistance Support: \(capabilities.supportsCameraAssistance ? "✅ YES" : "❌ NO")")
            NSLog("   - Direction Support: \(capabilities.supportsDirectionMeasurement ? "✅ YES" : "❌ NO")")
            NSLog("   - Precise Distance Support: \(capabilities.supportsPreciseDistanceMeasurement ? "✅ YES" : "❌ NO")")
            
            // CRITICAL: Check if device actually supports direction
            if !capabilities.supportsDirectionMeasurement {
                NSLog("\n❌❌❌ CRITICAL: This device DOES NOT support direction measurements!")
                NSLog("   Direction requires iPhone Pro models:")
                NSLog("   ✅ iPhone 11 Pro/Pro Max or newer Pro models")
                NSLog("   ❌ Regular iPhone 11/12/13/14/15 do NOT support direction")
                NSLog("   You can only get DISTANCE, not DIRECTION on this device!")
                
                DispatchQueue.main.async {
                    self.coachingMessage = "⚠️ Device doesn't support direction - Pro model required"
                }
            }
            
            let canEnableCamera = capabilities.supportsCameraAssistance && cameraAuthStatus == .authorized
            config.isCameraAssistanceEnabled = canEnableCamera
            
            NSLog("\n🎯 CONFIGURATION RESULT:")
            if canEnableCamera && capabilities.supportsDirectionMeasurement {
                NSLog("   ✅✅✅ Camera assistance ENABLED - Direction WILL work!")
            } else if canEnableCamera && !capabilities.supportsDirectionMeasurement {
                NSLog("   ⚠️ Camera assistance enabled but device doesn't support direction")
                NSLog("   Only DISTANCE will work, not DIRECTION")
            } else if !capabilities.supportsCameraAssistance {
                NSLog("   ❌❌❌ Device CANNOT support camera assistance")
            } else if cameraAuthStatus != .authorized {
                NSLog("   ❌❌❌ Camera assistance DISABLED - No camera permission!")
            }
            
            NSLog("   - config.isCameraAssistanceEnabled = \(config.isCameraAssistanceEnabled)")
        } else {
            NSLog("   ⚠️ iOS 15 or below - limited direction support")
        }
        
        NSLog("\n🚀 RUNNING SESSION:")
        NSLog("   - Session object: \(session)")
        NSLog("   - Delegate attached: \(session.delegate != nil)")
        NSLog("   - My token exists: \(myDiscoveryToken != nil)")
        NSLog("   - Peer token exists: \(peerDiscoveryToken != nil)")
        NSLog("   - Configuration camera enabled: \(config.isCameraAssistanceEnabled)")
        
        // Save configuration for re-running after suspension
        currentConfiguration = config
        
        // This is the critical call that starts ranging
        session.run(config)
        
        NSLog("   ✅ session.run(config) called")
        
        DispatchQueue.main.async {
            self.isRunning = true
            self.connectionState = "Ranging active"
        }
        
        NSLog("========== RANGING STARTED ==========\n")
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
        NSLog("\n🔄 UPDATE RECEIVED - ANALYZING...")
        NSLog("   Objects count: \(nearbyObjects.count)")
        
        guard let object = nearbyObjects.first else { 
            NSLog("   ❌ No nearby objects in update")
            return 
        }
        
        // Diagnostic summary
        NSLog("\n📊 MEASUREMENT STATUS:")
        NSLog("   - Distance available: \(object.distance != nil ? "✅ YES (\(object.distance!) meters)" : "❌ NO")")
        NSLog("   - Direction available: \(object.direction != nil ? "✅ YES" : "❌ NO")")
        
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
            @unknown default:
                NSLog("DELEGATE: verticalDirectionEstimate: unhandled case")
                verticalEstimateStr = "Unknown"
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
            
            // DIAGNOSTIC SUMMARY
            if object.distance != nil && object.direction == nil {
                NSLog("\n⚠️ DIAGNOSIS: Distance works but NO direction!")
                NSLog("   POSSIBLE CAUSES:")
                NSLog("   1. Camera permission denied on THIS device")
                NSLog("   2. Camera permission denied on PEER device")  
                NSLog("   3. Device doesn't support camera assistance")
                NSLog("   4. Camera assistance not enabled in config")
                NSLog("   5. Need to move device for convergence")
                NSLog("   CHECK: Both devices need camera permission!")
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