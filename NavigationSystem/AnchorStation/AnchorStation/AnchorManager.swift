//
//  AnchorManager.swift
//  Manages Nearby Interaction sessions for anchor stations
//

import Foundation
import NearbyInteraction
import MultipeerConnectivity
import Combine

class AnchorManager: NSObject, ObservableObject {
    // Published properties for UI
    @Published var isActive = false
    @Published var connectedPeer: String?
    @Published var lastDistance: Float?
    @Published var lastDirection: Float?
    
    // Anchor properties
    private var anchorID: String = ""
    private var position: CGPoint = .zero
    
    // Nearby Interaction
    private var niSession: NISession?
    private var peerToken: NIDiscoveryToken?
    
    // Multipeer Connectivity
    private var mcSession: MCSession?
    private var mcAdvertiser: MCNearbyServiceAdvertiser?
    private let serviceType = "nav-anchor"
    
    override init() {
        super.init()
    }
    
    func start(anchorID: String, position: CGPoint) {
        self.anchorID = anchorID
        self.position = position
        
        // Start Nearby Interaction session
        setupNearbyInteraction()
        
        // Start advertising via Multipeer Connectivity
        setupMultipeerConnectivity()
        
        isActive = true
    }
    
    func stop() {
        niSession?.invalidate()
        niSession = nil
        
        mcAdvertiser?.stopAdvertisingPeer()
        mcAdvertiser = nil
        
        mcSession?.disconnect()
        mcSession = nil
        
        isActive = false
        connectedPeer = nil
        lastDistance = nil
        lastDirection = nil
    }
    
    private func setupNearbyInteraction() {
        // Check if Nearby Interaction is supported
        guard NISession.isSupported else {
            print("Nearby Interaction is not supported on this device")
            return
        }
        
        // Create session
        niSession = NISession()
        niSession?.delegate = self
        
        // Generate discovery token for sharing
        guard let token = niSession?.discoveryToken else {
            print("Failed to create discovery token")
            return
        }
        
        print("NI Session created with token")
    }
    
    private func setupMultipeerConnectivity() {
        let peerID = MCPeerID(displayName: anchorID)
        
        // Create session
        mcSession = MCSession(peer: peerID, 
                              securityIdentity: nil,
                              encryptionPreference: .required)
        mcSession?.delegate = self
        
        // Start advertising
        let discoveryInfo: [String: String] = [
            "anchorID": anchorID,
            "x": String(position.x),
            "y": String(position.y)
        ]
        
        mcAdvertiser = MCNearbyServiceAdvertiser(peer: peerID,
                                                 discoveryInfo: discoveryInfo,
                                                 serviceType: serviceType)
        mcAdvertiser?.delegate = self
        mcAdvertiser?.startAdvertisingPeer()
        
        print("Started advertising as \(anchorID)")
    }
    
    private func shareDiscoveryToken() {
        guard let session = mcSession,
              let token = niSession?.discoveryToken else { return }
        
        do {
            let tokenData = try NSKeyedArchiver.archivedData(withRootObject: token,
                                                            requiringSecureCoding: true)
            try session.send(tokenData, toPeers: session.connectedPeers, with: .reliable)
            print("Shared discovery token with peer")
        } catch {
            print("Failed to share token: \(error)")
        }
    }
    
    private func receivedDiscoveryToken(_ data: Data) {
        do {
            guard let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self,
                                                                     from: data) else {
                print("Failed to decode token")
                return
            }
            
            peerToken = token
            
            // Create configuration and run session
            let config = NINearbyPeerConfiguration(peerToken: token)
            niSession?.run(config)
            
            print("Started NI session with peer token")
        } catch {
            print("Failed to receive token: \(error)")
        }
    }
}

// MARK: - NISessionDelegate
extension AnchorManager: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else { return }
        
        DispatchQueue.main.async {
            self.lastDistance = object.distance
            
            if let direction = object.direction {
                // Calculate angle from direction vector
                let angle = atan2(direction.y, direction.x)
                self.lastDirection = angle
            }
        }
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        DispatchQueue.main.async {
            self.lastDistance = nil
            self.lastDirection = nil
        }
    }
    
    func sessionWasSuspended(_ session: NISession) {
        print("NI Session suspended")
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        print("NI Session resumed")
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        print("NI Session invalidated: \(error)")
    }
}

// MARK: - MCSessionDelegate
extension AnchorManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.connectedPeer = peerID.displayName
                self.shareDiscoveryToken()
            case .notConnected:
                self.connectedPeer = nil
                self.lastDistance = nil
                self.lastDirection = nil
            default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Check if this is a discovery token
        if data.count > 100 {  // Tokens are typically larger
            receivedDiscoveryToken(data)
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension AnchorManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept invitations
        invitationHandler(true, mcSession)
        print("Accepted invitation from \(peerID.displayName)")
    }
}