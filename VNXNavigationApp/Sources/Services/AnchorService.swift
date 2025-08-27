import Foundation
import MultipeerConnectivity
import Combine
import NearbyInteraction

class AnchorService: MultipeerService {
    static let shared = AnchorService()
    
    private var advertiser: MCNearbyServiceAdvertiser?
    @Published var isAdvertising = false
    @Published var advertisingStatus = "Not advertising"
    
    let niSessionService = NISessionService()
    @Published var connectedNavigator: MCPeerID?
    
    override init() {
        super.init()
    }
    
    func startAdvertising(anchorID: String) {
        let displayName = "anchor:\(anchorID)"
        setupPeerID(displayName: displayName)
        
        guard let peerID = peerID else {
            print("❌ Failed to create peer ID")
            return
        }
        
        let discoveryInfo = [
            "role": "anchor",
            "anchorId": anchorID
        ]
        
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: discoveryInfo,
            serviceType: MultipeerService.serviceType
        )
        
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        
        DispatchQueue.main.async {
            self.isAdvertising = true
            self.advertisingStatus = "Advertising as \(displayName)"
            self.connectionStatus = "Advertising - waiting for connections"
        }
        
        print("📢 Started advertising as anchor: \(displayName)")
    }
    
    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        
        DispatchQueue.main.async {
            self.isAdvertising = false
            self.advertisingStatus = "Not advertising"
        }
        
        print("🛑 Stopped advertising")
    }
    
    override func cleanup() {
        stopAdvertising()
        niSessionService.stopSession()
        super.cleanup()
    }
    
    override func handleTokenExchange(_ tokenExchange: TokenExchange, from peerID: MCPeerID, session: MCSession) {
        super.handleTokenExchange(tokenExchange, from: peerID, session: session)
        
        if tokenExchange.type == "ni_token_request" {
            print("📍 Received NI token request from \(peerID.displayName)")
            
            connectedNavigator = peerID
            
            // IMPORTANT: Create our session FIRST before processing peer token
            guard let myTokenData = niSessionService.startSession(for: peerID) else {
                print("❌ Failed to generate anchor token")
                return
            }
            
            // Now process the peer's token with our existing session
            niSessionService.receivePeerToken(tokenExchange.token, from: peerID)
            
            let responseToken = TokenExchange(
                type: "ni_token_response",
                token: myTokenData,
                peerName: self.peerID?.displayName ?? "Unknown",
                timestamp: Date()
            )
            
            do {
                let data = try JSONEncoder().encode(responseToken)
                try session.send(data, toPeers: [peerID], with: .reliable)
                print("📤 Sent NI token response to \(peerID.displayName)")
            } catch {
                print("❌ Failed to send token response: \(error)")
            }
        }
    }
}

extension AnchorService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        
        print("📩 Received invitation from: \(peerID.displayName)")
        
        if peerID.displayName.hasPrefix("nav:") {
            print("✅ Accepting invitation from navigator: \(peerID.displayName)")
            invitationHandler(true, session)
        } else {
            print("❌ Rejecting invitation from non-navigator: \(peerID.displayName)")
            invitationHandler(false, nil)
        }
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("❌ Failed to start advertising: \(error)")
        
        DispatchQueue.main.async {
            self.isAdvertising = false
            self.advertisingStatus = "Failed to advertise: \(error.localizedDescription)"
        }
    }
}