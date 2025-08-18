//
//  NavigationManager.swift
//  Manages navigation to destinations using Nearby Interaction
//

import Foundation
import NearbyInteraction
import MultipeerConnectivity
import Combine
import CoreGraphics
import UIKit

class NavigationManager: NSObject, ObservableObject {
    @Published var currentDistance: Float?
    @Published var currentDirection: Float?
    @Published var isConnected = false
    @Published var targetDestination: String?
    
    // Nearby Interaction
    private var niSession: NISession?
    private var currentToken: NIDiscoveryToken?
    
    // Multipeer Connectivity
    private var mcSession: MCSession?
    private var mcBrowser: MCNearbyServiceBrowser?
    private let serviceType = "nav-anchor"
    
    // Navigation state
    private var connectedAnchors: [String: NIDiscoveryToken] = [:]
    private var anchorPositions: [String: CGPoint] = [:]
    
    override init() {
        super.init()
    }
    
    func startNavigation(to destination: String) {
        targetDestination = destination
        
        // Setup Nearby Interaction
        setupNearbyInteraction()
        
        // Start browsing for anchors
        setupMultipeerBrowsing()
    }
    
    func stop() {
        niSession?.invalidate()
        niSession = nil
        
        mcBrowser?.stopBrowsingForPeers()
        mcBrowser = nil
        
        mcSession?.disconnect()
        mcSession = nil
        
        isConnected = false
        currentDistance = nil
        currentDirection = nil
        targetDestination = nil
        connectedAnchors.removeAll()
        anchorPositions.removeAll()
    }
    
    private func setupNearbyInteraction() {
        guard NISession.isSupported else {
            print("Nearby Interaction is not supported on this device")
            return
        }
        
        niSession = NISession()
        niSession?.delegate = self
        currentToken = niSession?.discoveryToken
        
        print("Navigation NI Session created")
    }
    
    private func setupMultipeerBrowsing() {
        let peerID = MCPeerID(displayName: UIDevice.current.name)
        
        mcSession = MCSession(peer: peerID,
                              securityIdentity: nil,
                              encryptionPreference: .required)
        mcSession?.delegate = self
        
        mcBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        mcBrowser?.delegate = self
        mcBrowser?.startBrowsingForPeers()
        
        print("Started browsing for anchors")
    }
    
    private func shareDiscoveryToken(with peer: MCPeerID) {
        guard let session = mcSession,
              let token = currentToken else { return }
        
        do {
            let tokenData = try NSKeyedArchiver.archivedData(withRootObject: token,
                                                            requiringSecureCoding: true)
            try session.send(tokenData, toPeers: [peer], with: .reliable)
            print("Shared discovery token with \(peer.displayName)")
        } catch {
            print("Failed to share token: \(error)")
        }
    }
    
    private func receivedDiscoveryToken(_ data: Data, from peerID: MCPeerID) {
        do {
            guard let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self,
                                                                     from: data) else {
                print("Failed to decode token")
                return
            }
            
            connectedAnchors[peerID.displayName] = token
            
            // If this is our target destination, start NI session with it
            if peerID.displayName == targetDestination {
                let config = NINearbyPeerConfiguration(peerToken: token)
                niSession?.run(config)
                print("Started NI session with target: \(peerID.displayName)")
            }
        } catch {
            print("Failed to receive token: \(error)")
        }
    }
}

// MARK: - NISessionDelegate
extension NavigationManager: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else { return }
        
        DispatchQueue.main.async {
            self.currentDistance = object.distance
            
            if let direction = object.direction {
                // Calculate angle for arrow rotation
                let angle = atan2(direction.x, direction.z)
                self.currentDirection = angle
            }
            
            self.isConnected = true
        }
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        DispatchQueue.main.async {
            self.currentDistance = nil
            self.currentDirection = nil
            
            if reason == .timeout {
                self.isConnected = false
            }
        }
    }
    
    func sessionWasSuspended(_ session: NISession) {
        print("Navigation NI Session suspended")
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        print("Navigation NI Session resumed")
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        print("Navigation NI Session invalidated: \(error)")
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
}

// MARK: - MCSessionDelegate
extension NavigationManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("Connected to anchor: \(peerID.displayName)")
                self.shareDiscoveryToken(with: peerID)
            case .notConnected:
                print("Disconnected from anchor: \(peerID.displayName)")
                self.connectedAnchors.removeValue(forKey: peerID.displayName)
                if peerID.displayName == self.targetDestination {
                    self.isConnected = false
                    self.currentDistance = nil
                    self.currentDirection = nil
                }
            default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Check if this is a discovery token
        if data.count > 100 {
            receivedDiscoveryToken(data, from: peerID)
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceBrowserDelegate
extension NavigationManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("Found anchor: \(peerID.displayName)")
        
        // Store anchor position if available
        if let info = info,
           let xStr = info["x"], let x = Double(xStr),
           let yStr = info["y"], let y = Double(yStr) {
            anchorPositions[peerID.displayName] = CGPoint(x: x, y: y)
        }
        
        // Invite the peer if it's our target
        if peerID.displayName == targetDestination {
            browser.invitePeer(peerID, to: mcSession!, withContext: nil, timeout: 30)
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("Lost anchor: \(peerID.displayName)")
        anchorPositions.removeValue(forKey: peerID.displayName)
    }
}