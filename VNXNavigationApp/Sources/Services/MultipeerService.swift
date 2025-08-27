import Foundation
import MultipeerConnectivity
import Combine

struct ConnectedPeer: Identifiable {
    let id = UUID()
    let peerID: MCPeerID
    let displayName: String
    let connectedAt: Date
    var lastPingTime: Date?
    
    init(peerID: MCPeerID) {
        self.peerID = peerID
        self.displayName = peerID.displayName
        self.connectedAt = Date()
    }
}

class MultipeerService: NSObject, ObservableObject {
    static let serviceType = "vnx"
    
    @Published var connectedPeers: [ConnectedPeer] = []
    @Published var connectionStatus = "Not connected"
    @Published var isConnected = false
    
    var peerID: MCPeerID?
    var session: MCSession?
    
    override init() {
        super.init()
    }
    
    func setupPeerID(displayName: String) {
        peerID = MCPeerID(displayName: displayName)
        
        guard let peerID = peerID else { return }
        
        session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session?.delegate = self
    }
    
    func sendPing(to peer: MCPeerID) {
        guard let session = session else { return }
        
        let pingData = "PING:\(Date().timeIntervalSince1970)".data(using: .utf8)!
        
        do {
            try session.send(pingData, toPeers: [peer], with: .reliable)
            print("📡 Sent ping to \(peer.displayName)")
        } catch {
            print("❌ Failed to send ping: \(error)")
        }
    }
    
    func disconnect() {
        session?.disconnect()
        connectedPeers.removeAll()
        isConnected = false
        connectionStatus = "Disconnected"
    }
    
    func cleanup() {
        disconnect()
        session = nil
        peerID = nil
    }
}

extension MultipeerService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch state {
            case .notConnected:
                print("🔴 Disconnected from \(peerID.displayName)")
                self.connectedPeers.removeAll { $0.peerID == peerID }
                self.isConnected = !self.connectedPeers.isEmpty
                self.connectionStatus = self.connectedPeers.isEmpty ? "Not connected" : "Connected to \(self.connectedPeers.count) peer(s)"
                
            case .connecting:
                print("🟡 Connecting to \(peerID.displayName)")
                self.connectionStatus = "Connecting to \(peerID.displayName)..."
                
            case .connected:
                print("🟢 Connected to \(peerID.displayName)")
                if !self.connectedPeers.contains(where: { $0.peerID == peerID }) {
                    self.connectedPeers.append(ConnectedPeer(peerID: peerID))
                }
                self.isConnected = true
                self.connectionStatus = "Connected to \(self.connectedPeers.count) peer(s)"
                
                self.sendPing(to: peerID)
                
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = String(data: data, encoding: .utf8) else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if message.hasPrefix("PING:") {
                print("📨 Received ping from \(peerID.displayName)")
                
                let pongData = "PONG:\(Date().timeIntervalSince1970)".data(using: .utf8)!
                try? session.send(pongData, toPeers: [peerID], with: .reliable)
                
                if let index = self.connectedPeers.firstIndex(where: { $0.peerID == peerID }) {
                    self.connectedPeers[index].lastPingTime = Date()
                }
                
            } else if message.hasPrefix("PONG:") {
                print("📨 Received pong from \(peerID.displayName)")
                
                if let index = self.connectedPeers.firstIndex(where: { $0.peerID == peerID }) {
                    self.connectedPeers[index].lastPingTime = Date()
                }
                
                DispatchQueue.main.async {
                    self.connectionStatus = "Connection established with \(peerID.displayName)"
                }
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
    }
}