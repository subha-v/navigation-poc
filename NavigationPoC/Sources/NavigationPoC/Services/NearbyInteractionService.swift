import Foundation
import NearbyInteraction
import MultipeerConnectivity
import Combine
import CoreGraphics
import simd

class NearbyInteractionService: NSObject, ObservableObject {
    static let shared = NearbyInteractionService()
    
    @Published var isSessionActive = false
    @Published var connectedAnchors: [String: AnchorConnection] = [:]
    @Published var currentPosition: CGPoint?
    @Published var positionConfidence: Double = 0.0
    
    // Nearby Interaction
    private var niSessions: [String: NISession] = [:]
    private var discoveryToken: NIDiscoveryToken?
    
    // Multipeer Connectivity
    private var mcSession: MCSession?
    private var mcAdvertiser: MCNearbyServiceAdvertiser?
    private var mcBrowser: MCNearbyServiceBrowser?
    private let serviceType = "vnx-nav"
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    
    // Coordinate transformation
    private let coordinateTransform = CoordinateTransformService()
    
    // For anchors
    private var isAnchorMode = false
    private var anchorLocation: Location?
    
    struct AnchorConnection {
        let id: String
        let location: Location
        var distance: Float?
        var direction: simd_float3?
        var lastUpdate: Date
    }
    
    override private init() {
        super.init()
    }
    
    // MARK: - Anchor Mode
    
    func startAnchorMode(at location: Location) {
        isAnchorMode = true
        anchorLocation = location
        
        guard NISession.isSupported else {
            print("Nearby Interaction not supported on this device")
            return
        }
        
        // Create NI session for token generation
        let session = NISession()
        session.delegate = self
        discoveryToken = session.discoveryToken
        niSessions["anchor"] = session
        
        // Start advertising as anchor
        setupMultipeerAdvertising()
        isSessionActive = true
    }
    
    // MARK: - Tagger Mode
    
    func startTaggerMode() {
        isAnchorMode = false
        
        guard NISession.isSupported else {
            print("Nearby Interaction not supported on this device")
            return
        }
        
        // Start browsing for anchors
        setupMultipeerBrowsing()
        isSessionActive = true
    }
    
    func stopSession() {
        // Stop all NI sessions
        for (_, session) in niSessions {
            session.invalidate()
        }
        niSessions.removeAll()
        
        // Stop multipeer
        mcAdvertiser?.stopAdvertisingPeer()
        mcBrowser?.stopBrowsingForPeers()
        mcSession?.disconnect()
        
        mcAdvertiser = nil
        mcBrowser = nil
        mcSession = nil
        
        connectedAnchors.removeAll()
        currentPosition = nil
        positionConfidence = 0.0
        isSessionActive = false
    }
    
    // MARK: - Multipeer Setup
    
    private func setupMultipeerAdvertising() {
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession?.delegate = self
        
        var discoveryInfo: [String: String] = [:]
        if let location = anchorLocation {
            discoveryInfo["x"] = String(location.position.x)
            discoveryInfo["y"] = String(location.position.y)
            discoveryInfo["name"] = location.name
        }
        
        mcAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        mcAdvertiser?.delegate = self
        mcAdvertiser?.startAdvertisingPeer()
        
        print("Started advertising as anchor at \(anchorLocation?.name ?? "unknown")")
    }
    
    private func setupMultipeerBrowsing() {
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession?.delegate = self
        
        mcBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        mcBrowser?.delegate = self
        mcBrowser?.startBrowsingForPeers()
        
        print("Started browsing for anchors")
    }
    
    // MARK: - Token Exchange
    
    private func shareDiscoveryToken(with peer: MCPeerID) {
        guard let session = mcSession, let token = discoveryToken else { return }
        
        do {
            let tokenData = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            try session.send(tokenData, toPeers: [peer], with: .reliable)
            print("Shared discovery token with \(peer.displayName)")
        } catch {
            print("Failed to share token: \(error)")
        }
    }
    
    private func receivedDiscoveryToken(_ data: Data, from peerID: MCPeerID, anchorInfo: [String: String]?) {
        do {
            guard let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else {
                print("Failed to decode token")
                return
            }
            
            // Parse anchor location
            guard let xStr = anchorInfo?["x"], let x = Double(xStr),
                  let yStr = anchorInfo?["y"], let y = Double(yStr),
                  let name = anchorInfo?["name"] else {
                print("Missing anchor location info")
                return
            }
            
            let location = Location(id: peerID.displayName, name: name, x: x, y: y)
            
            // Create NI session for this anchor
            let session = NISession()
            session.delegate = self
            niSessions[peerID.displayName] = session
            
            // Start ranging
            let config = NINearbyPeerConfiguration(peerToken: token)
            session.run(config)
            
            // Store anchor connection
            DispatchQueue.main.async {
                self.connectedAnchors[peerID.displayName] = AnchorConnection(
                    id: peerID.displayName,
                    location: location,
                    distance: nil,
                    direction: nil,
                    lastUpdate: Date()
                )
            }
            
            print("Started NI session with anchor: \(name) at (\(x), \(y))")
            
        } catch {
            print("Failed to receive token: \(error)")
        }
    }
    
    // MARK: - Position Calculation
    
    private func updatePosition() {
        // Need at least 3 anchors for trilateration
        let activeAnchors = connectedAnchors.values.filter { 
            $0.distance != nil && Date().timeIntervalSince($0.lastUpdate) < 2.0
        }
        
        guard activeAnchors.count >= 3 else {
            positionConfidence = Double(activeAnchors.count) / 3.0
            return
        }
        
        // Perform trilateration
        let position = coordinateTransform.calculatePosition(from: Array(activeAnchors))
        
        DispatchQueue.main.async {
            self.currentPosition = position
            self.positionConfidence = min(1.0, Double(activeAnchors.count) / 3.0)
        }
    }
}

// MARK: - NISessionDelegate

extension NearbyInteractionService: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else { return }
        
        // Find which anchor this session belongs to
        var anchorID: String?
        for (id, niSession) in niSessions {
            if niSession === session {
                anchorID = id
                break
            }
        }
        
        guard let anchor = anchorID,
              var connection = connectedAnchors[anchor] else { return }
        
        // Update measurements
        connection.distance = object.distance
        connection.direction = object.direction
        connection.lastUpdate = Date()
        
        DispatchQueue.main.async {
            self.connectedAnchors[anchor] = connection
            self.updatePosition()
        }
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        print("NI objects removed: \(reason)")
    }
    
    func sessionWasSuspended(_ session: NISession) {
        print("NI session suspended")
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        print("NI session resumed")
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        print("NI session invalidated: \(error)")
    }
}

// MARK: - MCSessionDelegate

extension NearbyInteractionService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            print("Connected to peer: \(peerID.displayName)")
            if isAnchorMode {
                shareDiscoveryToken(with: peerID)
            }
        case .notConnected:
            print("Disconnected from peer: \(peerID.displayName)")
            DispatchQueue.main.async {
                self.connectedAnchors.removeValue(forKey: peerID.displayName)
                self.niSessions.removeValue(forKey: peerID.displayName)
            }
        default:
            break
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Assume this is a discovery token
        if !isAnchorMode && data.count > 100 {
            // Try to get anchor info from the browser's discovered peers
            receivedDiscoveryToken(data, from: peerID, anchorInfo: nil)
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension NearbyInteractionService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, mcSession)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension NearbyInteractionService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("Found anchor: \(peerID.displayName)")
        browser.invitePeer(peerID, to: mcSession!, withContext: nil, timeout: 30)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("Lost anchor: \(peerID.displayName)")
    }
}