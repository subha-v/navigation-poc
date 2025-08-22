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
    @Published var connectionState: ConnectionState = .disconnected
    
    enum ConnectionState {
        case disconnected
        case searching
        case connected
    }
    
    private var niSession: NISession?
    private var mcSession: MCSession?
    private var mcAdvertiser: MCNearbyServiceAdvertiser?
    private var mcBrowser: MCNearbyServiceBrowser?
    private let serviceType = "vnx-nav"
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private var peerTokens: [MCPeerID: NIDiscoveryToken] = [:]
    private var searchTimer: Timer?
    
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
        connectionState = .searching
        
        // Start timeout timer for "no anchor found"
        searchTimer?.invalidate()
        searchTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            Task { @MainActor in
                if self.connectionState == .searching {
                    self.connectionState = .disconnected
                }
            }
        }
    }
    
    func stopSession() {
        niSession?.invalidate()
        niSession = nil
        
        mcAdvertiser?.stopAdvertisingPeer()
        mcBrowser?.stopBrowsingForPeers()
        
        isRunning = false
        connectionState = .disconnected
        peerTokens.removeAll()
        searchTimer?.invalidate()
        searchTimer = nil
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
                
                // Send our discovery token to the newly connected peer
                if let token = self.niSession?.discoveryToken {
                    do {
                        let tokenData = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
                        try await self.mcSession?.send(tokenData, toPeers: [peerID], with: .reliable)
                        print("Sent discovery token to \(peerID.displayName)")
                    } catch {
                        print("Failed to send discovery token: \(error)")
                    }
                }
            } else if state == .notConnected {
                self.connectedPeers.removeAll { $0 == peerID }
                self.peerTokens.removeValue(forKey: peerID)
                
                // Update connection state if no peers left
                if self.connectedPeers.isEmpty {
                    self.connectionState = self.isRunning ? .searching : .disconnected
                    self.distance = nil
                    self.direction = nil
                }
            }
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Handle discovery token exchange
        Task { @MainActor in
            do {
                if let discoveryToken = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
                    // Store peer token
                    self.peerTokens[peerID] = discoveryToken
                    
                    // Configure and run NISession with peer token
                    let config = NINearbyPeerConfiguration(peerToken: discoveryToken)
                    self.niSession?.run(config)
                    
                    // Update connection state
                    self.connectionState = .connected
                    self.searchTimer?.invalidate()
                    
                    print("Configured NISession with peer token from \(peerID.displayName)")
                }
            } catch {
                print("Failed to decode discovery token: \(error)")
            }
        }
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