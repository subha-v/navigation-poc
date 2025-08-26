import Foundation
import NearbyInteraction
import MultipeerConnectivity
import SwiftUI
import os.log

@MainActor
class NearbyInteractionService: NSObject, ObservableObject {
    static let shared = NearbyInteractionService()
    private let logger = Logger(subsystem: "com.valuenex.VNXNavigationApp", category: "NearbyInteraction")
    
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
    private var myDiscoveryToken: NIDiscoveryToken?
    
    override private init() {
        super.init()
        setupMultipeerConnectivity()
    }
    
    func startSession() {
        guard NISession.isSupported else {
            logger.error("❌ Nearby Interaction not supported on this device")
            return
        }
        
        logger.info("✅ Starting Nearby Interaction session")
        logger.info("📱 Device name: \(peerID.displayName)")
        logger.info("📡 Service type: \(serviceType)")
        
        niSession = NISession()
        niSession?.delegate = self
        
        // Generate and store our discovery token
        if let token = niSession?.discoveryToken {
            myDiscoveryToken = token
            logger.info("🔑 Discovery token generated successfully")
        } else {
            logger.warning("⚠️ Discovery token not yet available")
        }
        
        // Start advertising/browsing
        mcAdvertiser?.startAdvertisingPeer()
        mcBrowser?.startBrowsingForPeers()
        
        logger.info("🔍 Started advertising and browsing for peers")
        
        isRunning = true
        connectionState = .searching
        
        // Start timeout timer for "no anchor found"
        searchTimer?.invalidate()
        searchTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            Task { @MainActor in
                if self.connectionState == .searching {
                    self.connectionState = .disconnected
                    self.logger.warning("⏱️ Search timeout - no peers found")
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
            
            self.logger.info("📏 Distance update: \(object.distance ?? -1) meters")
            self.distance = object.distance
            self.direction = object.direction
        }
    }
    
    nonisolated func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        Task { @MainActor in
            self.logger.info("🔴 Nearby object removed, reason: \(reason.rawValue)")
            self.distance = nil
            self.direction = nil
        }
    }
    
    nonisolated func session(_ session: NISession, didGenerateShareableConfigurationData data: Data, for object: NINearbyObject) {
        // This is called when generating shareable configuration data
        logger.info("📊 Generated shareable configuration data")
    }
    
    nonisolated func sessionWasSuspended(_ session: NISession) {
        logger.warning("⏸️ NISession was suspended")
    }
    
    nonisolated func sessionSuspensionEnded(_ session: NISession) {
        logger.info("▶️ NISession suspension ended")
    }
    
    nonisolated func session(_ session: NISession, didInvalidateWith error: Error) {
        logger.error("❌ NISession invalidated with error: \(error.localizedDescription)")
    }
}

// MARK: - MCSessionDelegate
extension NearbyInteractionService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            self.logger.info("🔄 Peer \(peerID.displayName) state changed to: \(state == .connected ? "Connected" : state == .connecting ? "Connecting" : "Not Connected")")
            
            if state == .connected {
                self.logger.info("✅ Successfully connected to peer: \(peerID.displayName)")
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                
                // Send our discovery token to the newly connected peer
                // First try to get a fresh token, fall back to stored one
                if let token = self.niSession?.discoveryToken ?? self.myDiscoveryToken {
                    do {
                        let tokenData = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
                        try await self.mcSession?.send(tokenData, toPeers: [peerID], with: .reliable)
                        self.logger.info("📤 Sent discovery token to \(peerID.displayName)")
                        self.logger.debug("📊 Token size: \(tokenData.count) bytes")
                    } catch {
                        self.logger.error("❌ Failed to send discovery token: \(error.localizedDescription)")
                    }
                } else {
                    self.logger.warning("⚠️ No discovery token available to send - NISession might not be properly initialized")
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
            self.logger.info("📥 Received data from \(peerID.displayName), size: \(data.count) bytes")
            
            do {
                if let discoveryToken = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
                    self.logger.info("✅ Successfully decoded discovery token from \(peerID.displayName)")
                    
                    // Store peer token
                    self.peerTokens[peerID] = discoveryToken
                    
                    // Make sure we have our own NISession
                    guard let niSession = self.niSession else {
                        self.logger.error("❌ No NISession available to configure")
                        return
                    }
                    
                    // Configure and run NISession with peer token
                    let config = NINearbyPeerConfiguration(peerToken: discoveryToken)
                    niSession.run(config)
                    
                    // Update connection state
                    self.connectionState = .connected
                    self.searchTimer?.invalidate()
                    
                    self.logger.info("🎯 Configured NISession with peer token from \(peerID.displayName)")
                    self.logger.info("🔄 NISession is now running with peer configuration")
                }
            } catch {
                self.logger.error("❌ Failed to decode discovery token: \(error.localizedDescription)")
                self.logger.debug("📊 Data size was: \(data.count) bytes")
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
            self.logger.info("🔍 Found peer: \(peerID.displayName)")
            guard let session = self.mcSession else { 
                self.logger.error("❌ No MC session available")
                return 
            }
            self.logger.info("📤 Inviting peer: \(peerID.displayName)")
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
        }
    }
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        logger.info("📵 Lost peer: \(peerID.displayName)")
    }
}