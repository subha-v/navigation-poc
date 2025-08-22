import Foundation
import NearbyInteraction
import MultipeerConnectivity
import SwiftUI

@MainActor
class NearbyInteractionService: NSObject, ObservableObject {
    static let shared = NearbyInteractionService()
    
    @Published var isRunning = false
    @Published var connectedPeers: [MCPeerID] = []
    @Published var distance: Float?
    @Published var direction: simd_float3?
    
    private var niSession: NISession?
    private var mcSession: MCSession?
    private var mcAdvertiser: MCNearbyServiceAdvertiser?
    private var mcBrowser: MCNearbyServiceBrowser?
    private let serviceType = "vnx-nav"
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    
    override private init() {
        super.init()
        setupMultipeerConnectivity()
    }
    
    func startSession() {
        guard NISession.isSupported else {
            print("Nearby Interaction not supported on this device")
            return
        }
        
        niSession = NISession()
        niSession?.delegate = self
        
        // Start advertising/browsing
        mcAdvertiser?.startAdvertisingPeer()
        mcBrowser?.startBrowsingForPeers()
        
        isRunning = true
    }
    
    func stopSession() {
        niSession?.invalidate()
        niSession = nil
        
        mcAdvertiser?.stopAdvertisingPeer()
        mcBrowser?.stopBrowsingForPeers()
        
        isRunning = false
    }
    
    private func setupMultipeerConnectivity() {
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession?.delegate = self
        
        mcAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        mcAdvertiser?.delegate = self
        
        mcBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        mcBrowser?.delegate = self
    }
}

// MARK: - NISessionDelegate
extension NearbyInteractionService: NISessionDelegate {
    nonisolated func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        Task { @MainActor in
            guard let object = nearbyObjects.first else { return }
            
            self.distance = object.distance
            self.direction = object.direction
        }
    }
    
    nonisolated func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        Task { @MainActor in
            self.distance = nil
            self.direction = nil
        }
    }
}

// MARK: - MCSessionDelegate
extension NearbyInteractionService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            if state == .connected {
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
            } else if state == .notConnected {
                self.connectedPeers.removeAll { $0 == peerID }
            }
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Handle discovery token exchange here
    }
    
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension NearbyInteractionService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            invitationHandler(true, self.mcSession)
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension NearbyInteractionService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        Task { @MainActor in
            guard let session = self.mcSession else { return }
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
        }
    }
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // Handle lost peer
    }
}