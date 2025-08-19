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
    @Published var currentPosition: CGPoint?
    @Published var currentDistance: Float?
    @Published var currentDirection: Float?
    @Published var isConnected = false
    @Published var targetDestination: String?
    @Published var connectedAnchorsCount: Int = 0
    @Published var navigationConfidence: Float = 0.0
    
    // Nearby Interaction - multiple sessions for multiple anchors
    private var niSessions: [String: NISession] = [:]
    private var currentToken: NIDiscoveryToken?
    
    // Multipeer Connectivity
    private var mcSession: MCSession?
    private var mcBrowser: MCNearbyServiceBrowser?
    private let serviceType = "nav-anchor"
    
    // Navigation state
    private var connectedAnchors: [String: NIDiscoveryToken] = [:]
    private var anchorPositions: [String: CGPoint] = [:]
    private var anchorMeasurements: [String: (distance: Float, direction: simd_float3?)] = [:]
    
    // Trilateration
    private let trilaterationEngine = TrilaterationEngine()
    private let anchorConfig = AnchorConfiguration.shared
    
    override init() {
        super.init()
    }
    
    func startNavigation(to destination: String? = nil) {
        targetDestination = destination
        
        // Setup main Nearby Interaction session for token generation
        setupNearbyInteraction()
        
        // Start browsing for all anchors
        setupMultipeerBrowsing()
    }
    
    func stop() {
        // Invalidate all NI sessions
        for (_, session) in niSessions {
            session.invalidate()
        }
        niSessions.removeAll()
        
        mcBrowser?.stopBrowsingForPeers()
        mcBrowser = nil
        
        mcSession?.disconnect()
        mcSession = nil
        
        isConnected = false
        currentPosition = nil
        currentDistance = nil
        currentDirection = nil
        targetDestination = nil
        connectedAnchors.removeAll()
        anchorPositions.removeAll()
        anchorMeasurements.removeAll()
        trilaterationEngine.reset()
        connectedAnchorsCount = 0
        navigationConfidence = 0.0
    }
    
    private func setupNearbyInteraction() {
        guard NISession.isSupported else {
            print("Nearby Interaction is not supported on this device")
            return
        }
        
        // Create a main session just for token generation
        let mainSession = NISession()
        currentToken = mainSession.discoveryToken
        
        print("Navigation NI token created")
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
            
            let anchorID = peerID.displayName
            connectedAnchors[anchorID] = token
            
            // Create a dedicated NI session for this anchor
            let session = NISession()
            session.delegate = self
            niSessions[anchorID] = session
            
            // Start ranging with this anchor
            let config = NINearbyPeerConfiguration(peerToken: token)
            session.run(config)
            
            print("Started NI session with anchor: \(anchorID)")
            
            DispatchQueue.main.async {
                self.connectedAnchorsCount = self.connectedAnchors.count
                self.isConnected = self.connectedAnchorsCount > 0
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
        
        // Find which anchor this session belongs to
        var anchorID: String?
        for (id, niSession) in niSessions {
            if niSession === session {
                anchorID = id
                break
            }
        }
        
        guard let anchor = anchorID,
              let anchorData = anchorConfig.getAnchor(byId: anchor) else { return }
        
        // Update measurement for this anchor
        if let distance = object.distance {
            anchorMeasurements[anchor] = (distance, object.direction)
            
            // Update trilateration engine
            trilaterationEngine.updateMeasurement(
                anchorId: anchor,
                position: anchorData.position,
                distance: distance,
                direction: object.direction
            )
        }
        
        // Calculate position using trilateration
        if let calculatedPosition = trilaterationEngine.calculatePosition() {
            DispatchQueue.main.async {
                self.currentPosition = calculatedPosition
                self.navigationConfidence = self.trilaterationEngine.getConfidenceLevel()
                
                // If we have a target, calculate distance and direction to it
                if let targetName = self.targetDestination,
                   let targetPOI = self.anchorConfig.getPOI(byName: targetName) {
                    let dx = targetPOI.position.x - calculatedPosition.x
                    let dy = targetPOI.position.y - calculatedPosition.y
                    self.currentDistance = Float(sqrt(dx * dx + dy * dy))
                    self.currentDirection = Float(atan2(dy, dx))
                }
            }
        }
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        // Find which anchor this session belongs to
        var anchorID: String?
        for (id, niSession) in niSessions {
            if niSession === session {
                anchorID = id
                break
            }
        }
        
        if let anchor = anchorID {
            anchorMeasurements.removeValue(forKey: anchor)
            
            DispatchQueue.main.async {
                if self.anchorMeasurements.isEmpty {
                    self.currentPosition = nil
                    self.currentDistance = nil
                    self.currentDirection = nil
                }
                self.navigationConfidence = self.trilaterationEngine.getConfidenceLevel()
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
        
        // Connect to all available anchors for trilateration
        // Only connect if it's one of our configured anchors
        if anchorConfig.getAnchor(byId: peerID.displayName) != nil {
            browser.invitePeer(peerID, to: mcSession!, withContext: nil, timeout: 30)
            print("Inviting anchor: \(peerID.displayName)")
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("Lost anchor: \(peerID.displayName)")
        anchorPositions.removeValue(forKey: peerID.displayName)
    }
}