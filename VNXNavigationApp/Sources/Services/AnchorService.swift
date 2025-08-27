import Foundation
import MultipeerConnectivity
import Combine

class AnchorService: MultipeerService {
    static let shared = AnchorService()
    
    private var advertiser: MCNearbyServiceAdvertiser?
    @Published var isAdvertising = false
    @Published var advertisingStatus = "Not advertising"
    
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
        super.cleanup()
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