import Foundation
import MultipeerConnectivity
import Combine

struct DiscoveredAnchor: Identifiable {
    let id = UUID()
    let peerID: MCPeerID
    let anchorID: String
    let displayName: String
    var isConnecting: Bool = false
}

class NavigatorService: MultipeerService {
    static let shared = NavigatorService()
    
    private var browser: MCNearbyServiceBrowser?
    @Published var discoveredAnchors: [DiscoveredAnchor] = []
    @Published var isBrowsing = false
    @Published var browsingStatus = "Not browsing"
    
    override init() {
        super.init()
    }
    
    func startBrowsing(navigatorID: String) {
        let displayName = "nav:\(navigatorID)"
        setupPeerID(displayName: displayName)
        
        guard let peerID = peerID else {
            print("❌ Failed to create peer ID")
            return
        }
        
        browser = MCNearbyServiceBrowser(
            peer: peerID,
            serviceType: MultipeerService.serviceType
        )
        
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        
        DispatchQueue.main.async {
            self.isBrowsing = true
            self.browsingStatus = "Browsing for anchors"
            self.connectionStatus = "Searching for anchors..."
        }
        
        print("🔍 Started browsing as navigator: \(displayName)")
    }
    
    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        
        DispatchQueue.main.async {
            self.isBrowsing = false
            self.browsingStatus = "Not browsing"
            self.discoveredAnchors.removeAll()
        }
        
        print("🛑 Stopped browsing")
    }
    
    func connectToAnchor(_ anchor: DiscoveredAnchor) {
        guard let session = session else {
            print("❌ No session available")
            return
        }
        
        DispatchQueue.main.async {
            if let index = self.discoveredAnchors.firstIndex(where: { $0.id == anchor.id }) {
                self.discoveredAnchors[index].isConnecting = true
            }
        }
        
        let context = "nav_connection".data(using: .utf8)
        
        browser?.invitePeer(
            anchor.peerID,
            to: session,
            withContext: context,
            timeout: 30
        )
        
        print("📤 Sent invitation to anchor: \(anchor.displayName)")
        
        DispatchQueue.main.async {
            self.connectionStatus = "Connecting to \(anchor.displayName)..."
        }
    }
    
    override func cleanup() {
        stopBrowsing()
        super.cleanup()
    }
}

extension NavigatorService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        
        guard let info = info,
              info["role"] == "anchor",
              let anchorId = info["anchorId"] else {
            print("⚠️ Found non-anchor peer: \(peerID.displayName)")
            return
        }
        
        DispatchQueue.main.async {
            if !self.discoveredAnchors.contains(where: { $0.peerID == peerID }) {
                let anchor = DiscoveredAnchor(
                    peerID: peerID,
                    anchorID: anchorId,
                    displayName: peerID.displayName
                )
                self.discoveredAnchors.append(anchor)
                print("✅ Found anchor: \(peerID.displayName) with ID: \(anchorId)")
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredAnchors.removeAll { $0.peerID == peerID }
            print("👋 Lost anchor: \(peerID.displayName)")
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("❌ Failed to start browsing: \(error)")
        
        DispatchQueue.main.async {
            self.isBrowsing = false
            self.browsingStatus = "Failed to browse: \(error.localizedDescription)"
        }
    }
}