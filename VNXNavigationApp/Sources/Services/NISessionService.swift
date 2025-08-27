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
    
    private var niSession: NISession?
    private var myDiscoveryToken: NIDiscoveryToken?
    private var peerDiscoveryToken: NIDiscoveryToken?
    private var currentPeerID: MCPeerID?
    
    override init() {
        super.init()
        checkDeviceCapabilities()
    }
    
    private func checkDeviceCapabilities() {
        guard NISession.isSupported else {
            print("❌ Nearby Interaction is not supported on this device")
            connectionState = "NI not supported on this device"
            return
        }
        print("✅ Nearby Interaction is supported")
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
        
        startRanging(with: token)
    }
    
    private func startRanging(with peerToken: NIDiscoveryToken) {
        guard let session = niSession else {
            print("❌ No NI session available")
            return
        }
        
        let config = NINearbyPeerConfiguration(peerToken: peerToken)
        
        print("DEBUG: About to run NI session")
        print("DEBUG: Session delegate is set: \(session.delegate != nil)")
        print("DEBUG: My token exists: \(myDiscoveryToken != nil)")
        print("DEBUG: Peer token received: \(peerDiscoveryToken != nil)")
        
        session.run(config)
        
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
                
                let azimuth = atan2(direction.y, direction.x)
                let elevation = asin(direction.z)
                self.azimuth = azimuth
                self.elevation = elevation
                
                print("MEASUREMENT: Distance: \(self.formatDistance()), Direction: \(self.formatDirection())")
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
        print("▶️ NI session resumed")
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        DispatchQueue.main.async {
            self.isRunning = false
            self.connectionState = "Session error: \(error.localizedDescription)"
        }
        print("❌ NI session invalidated: \(error)")
    }
}