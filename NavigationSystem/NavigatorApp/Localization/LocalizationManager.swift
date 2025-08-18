//
//  LocalizationManager.swift
//  Handles ARKit tracking and Nearby Interaction fusion for localization
//

import Foundation
import ARKit
import NearbyInteraction
import MultipeerConnectivity
import Combine

class LocalizationManager: NSObject, ObservableObject {
    // Published position for UI updates
    @Published var currentPosition: CGPoint = .zero
    @Published var currentHeading: Double = 0.0  // radians
    @Published var isLocalized = false
    @Published var trackingQuality: String = "Not Tracking"
    
    // Map data
    private var mapData: MapData?
    
    // ARKit
    private var arSession: ARSession?
    private var arConfiguration: ARWorldTrackingConfiguration?
    private var lastARTransform: simd_float4x4?
    private var arReferencePosition: CGPoint = .zero
    private var arReferenceHeading: Double = 0.0
    
    // Nearby Interaction
    private var niSession: NISession?
    private var anchorTokens: [String: NIDiscoveryToken] = [:]
    private var anchorPositions: [String: CGPoint] = [:]
    private var activeAnchors: Set<String> = []
    
    // Multipeer Connectivity
    private var mcSession: MCSession?
    private var mcBrowser: MCNearbyServiceBrowser?
    private let serviceType = "nav-anchor"
    
    // Fusion parameters
    private let niCorrectionGain: Double = 0.1  // 10% correction per update
    private var lastNIUpdate = Date()
    
    override init() {
        super.init()
        setupARKit()
        setupNearbyInteraction()
    }
    
    func setMapData(_ mapData: MapData) {
        self.mapData = mapData
        
        // Store anchor positions
        for anchor in mapData.anchors {
            anchorPositions[anchor.id] = anchor.position
        }
    }
    
    private func setupARKit() {
        arSession = ARSession()
        arSession?.delegate = self
        
        arConfiguration = ARWorldTrackingConfiguration()
        arConfiguration?.worldAlignment = .gravity
        arConfiguration?.planeDetection = []  // No plane detection needed
        
        arSession?.run(arConfiguration!)
    }
    
    private func setupNearbyInteraction() {
        guard NISession.isSupported else {
            print("Nearby Interaction not supported")
            return
        }
        
        niSession = NISession()
        niSession?.delegate = self
        
        // Setup Multipeer Connectivity for token exchange
        let peerID = MCPeerID(displayName: "Navigator-\(UUID().uuidString.prefix(4))")
        mcSession = MCSession(peer: peerID,
                              securityIdentity: nil,
                              encryptionPreference: .required)
        mcSession?.delegate = self
        
        mcBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        mcBrowser?.delegate = self
    }
    
    func startLocalization() {
        // Start browsing for anchors
        mcBrowser?.startBrowsingForPeers()
        print("Started browsing for anchors")
    }
    
    func stopLocalization() {
        mcBrowser?.stopBrowsingForPeers()
        mcSession?.disconnect()
        niSession?.invalidate()
        arSession?.pause()
        isLocalized = false
    }
    
    // Initialize position at a known anchor
    func initializeAtAnchor(_ anchorID: String) {
        guard let position = anchorPositions[anchorID] else { return }
        
        arReferencePosition = position
        arReferenceHeading = 0
        currentPosition = position
        currentHeading = 0
        isLocalized = true
        
        print("Initialized at anchor \(anchorID): \(position)")
    }
    
    // Update position from ARKit transform
    private func updateFromARKit(_ transform: simd_float4x4) {
        guard isLocalized else { return }
        
        // Extract translation from transform
        let translation = simd_float3(transform.columns.3.x, 
                                      transform.columns.3.y, 
                                      transform.columns.3.z)
        
        // Calculate heading from rotation matrix
        let forward = simd_float3(transform.columns.2.x,
                                  transform.columns.2.y, 
                                  transform.columns.2.z)
        let heading = atan2(Double(forward.x), Double(forward.z))
        
        // Apply to reference position
        let deltaX = Double(translation.x)
        let deltaZ = Double(translation.z)
        
        // Rotate by reference heading and add to reference position
        let cos_h = cos(arReferenceHeading)
        let sin_h = sin(arReferenceHeading)
        
        currentPosition = CGPoint(
            x: arReferencePosition.x + deltaX * cos_h - deltaZ * sin_h,
            y: arReferencePosition.y + deltaX * sin_h + deltaZ * cos_h
        )
        
        currentHeading = arReferenceHeading + heading
        
        // Ensure position stays in bounds
        if let mapData = mapData {
            if !mapData.isPositionFree(currentPosition) {
                // Snap to nearest free position
                currentPosition = findNearestFreePosition(currentPosition)
            }
        }
    }
    
    // Correct position using Nearby Interaction measurements
    private func correctWithNI(anchorID: String, distance: Float, direction: simd_float3?) {
        guard let anchorPos = anchorPositions[anchorID],
              Date().timeIntervalSince(lastNIUpdate) > 0.5 else { return }  // Limit update rate
        
        lastNIUpdate = Date()
        
        // Simple distance-based correction
        let currentDist = hypot(currentPosition.x - anchorPos.x,
                               currentPosition.y - anchorPos.y)
        
        if abs(currentDist - Double(distance)) > 0.5 {  // More than 0.5m error
            // Calculate corrected position
            let ratio = Double(distance) / currentDist
            let correctedX = anchorPos.x + (currentPosition.x - anchorPos.x) * ratio
            let correctedY = anchorPos.y + (currentPosition.y - anchorPos.y) * ratio
            
            // Apply correction with gain
            currentPosition.x += (correctedX - currentPosition.x) * niCorrectionGain
            currentPosition.y += (correctedY - currentPosition.y) * niCorrectionGain
            
            // Update AR reference
            arReferencePosition = currentPosition
            
            print("NI correction applied: distance error = \(abs(currentDist - Double(distance)))m")
        }
    }
    
    private func findNearestFreePosition(_ position: CGPoint) -> CGPoint {
        guard let mapData = mapData else { return position }
        
        // Search in expanding circles for free space
        let searchRadius = 2.0  // meters
        let steps = 16
        
        for r in stride(from: 0.1, to: searchRadius, by: 0.1) {
            for i in 0..<steps {
                let angle = Double(i) * 2.0 * .pi / Double(steps)
                let testPos = CGPoint(
                    x: position.x + r * cos(angle),
                    y: position.y + r * sin(angle)
                )
                
                if mapData.isPositionFree(testPos) {
                    return testPos
                }
            }
        }
        
        return position  // No free position found
    }
    
    private func shareDiscoveryToken() {
        guard let session = mcSession,
              let token = niSession?.discoveryToken else { return }
        
        do {
            let tokenData = try NSKeyedArchiver.archivedData(withRootObject: token,
                                                            requiringSecureCoding: true)
            try session.send(tokenData, toPeers: session.connectedPeers, with: .reliable)
            print("Shared discovery token with anchors")
        } catch {
            print("Failed to share token: \(error)")
        }
    }
    
    private func receivedDiscoveryToken(_ data: Data, from peerID: String) {
        do {
            guard let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self,
                                                                     from: data) else {
                print("Failed to decode token")
                return
            }
            
            anchorTokens[peerID] = token
            
            // Start NI session with this anchor
            let config = NINearbyPeerConfiguration(peerToken: token)
            niSession?.run(config)
            
            activeAnchors.insert(peerID)
            print("Started NI session with anchor: \(peerID)")
        } catch {
            print("Failed to receive token: \(error)")
        }
    }
}

// MARK: - ARSessionDelegate
extension LocalizationManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        lastARTransform = frame.camera.transform
        updateFromARKit(frame.camera.transform)
        
        // Update tracking quality
        DispatchQueue.main.async {
            switch frame.camera.trackingState {
            case .normal:
                self.trackingQuality = "Good"
            case .limited(let reason):
                switch reason {
                case .excessiveMotion:
                    self.trackingQuality = "Excessive Motion"
                case .insufficientFeatures:
                    self.trackingQuality = "Insufficient Features"
                case .initializing:
                    self.trackingQuality = "Initializing"
                case .relocalizing:
                    self.trackingQuality = "Relocalizing"
                @unknown default:
                    self.trackingQuality = "Limited"
                }
            case .notAvailable:
                self.trackingQuality = "Not Available"
            }
        }
    }
}

// MARK: - NISessionDelegate
extension LocalizationManager: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        for object in nearbyObjects {
            // Find which anchor this is
            for (anchorID, token) in anchorTokens {
                // Match by discovery token (simplified - in real app would need proper matching)
                if let distance = object.distance {
                    correctWithNI(anchorID: anchorID, 
                                 distance: distance,
                                 direction: object.direction)
                    break  // Only use first matching anchor
                }
            }
        }
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        // Handle removed objects if needed
    }
}

// MARK: - MCSessionDelegate
extension LocalizationManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            print("Connected to anchor: \(peerID.displayName)")
            shareDiscoveryToken()
        case .notConnected:
            print("Disconnected from anchor: \(peerID.displayName)")
            activeAnchors.remove(peerID.displayName)
        default:
            break
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if data.count > 100 {  // Likely a discovery token
            receivedDiscoveryToken(data, from: peerID.displayName)
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceBrowserDelegate
extension LocalizationManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        guard let info = info,
              let anchorID = info["anchorID"],
              let xStr = info["x"],
              let yStr = info["y"],
              let x = Double(xStr),
              let y = Double(yStr) else { return }
        
        // Store anchor position
        anchorPositions[anchorID] = CGPoint(x: x, y: y)
        
        // Invite to session
        browser.invitePeer(peerID, to: mcSession!, withContext: nil, timeout: 30)
        print("Found anchor \(anchorID) at (\(x), \(y))")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("Lost anchor: \(peerID.displayName)")
    }
}