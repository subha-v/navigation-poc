//
//  IndoorNavigation.swift
//  Main module entry point - Simple drop-in navigation
//

import SwiftUI
import NearbyInteraction
import ARKit
import MultipeerConnectivity

// MARK: - Main View that can be dropped into any app
public struct IndoorNavigationView: View {
    @State private var mode: NavigationMode = .navigator
    
    public init() {}
    
    public var body: some View {
        VStack {
            // Mode selector
            Picker("Mode", selection: $mode) {
                Text("Navigator").tag(NavigationMode.navigator)
                Text("Anchor").tag(NavigationMode.anchor)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Show appropriate view
            if mode == .anchor {
                SimpleAnchorView()
            } else {
                SimpleNavigatorView()
            }
        }
    }
}

public enum NavigationMode {
    case navigator
    case anchor
}

// MARK: - Simple Anchor View
struct SimpleAnchorView: View {
    @StateObject private var anchor = SimpleAnchor()
    @State private var anchorID = "A"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Anchor Station")
                .font(.largeTitle)
            
            TextField("Anchor ID", text: $anchorID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button(action: {
                if anchor.isActive {
                    anchor.stop()
                } else {
                    anchor.start(id: anchorID)
                }
            }) {
                Text(anchor.isActive ? "Stop" : "Start")
                    .foregroundColor(.white)
                    .frame(width: 200, height: 50)
                    .background(anchor.isActive ? Color.red : Color.green)
                    .cornerRadius(10)
            }
            
            if anchor.isActive {
                Text("Broadcasting as: \(anchorID)")
                if let distance = anchor.lastDistance {
                    Text("Distance: \(String(format: "%.2f m", distance))")
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Simple Navigator View  
struct SimpleNavigatorView: View {
    @StateObject private var navigator = SimpleNavigator()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Indoor Navigator")
                .font(.largeTitle)
            
            // Map display
            MapDisplayView(navigator: navigator)
                .frame(height: 400)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
            
            // Status
            HStack {
                Circle()
                    .fill(navigator.isTracking ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text(navigator.isTracking ? "Tracking" : "Not Tracking")
            }
            
            // Navigation controls
            HStack(spacing: 20) {
                Button("Start Tracking") {
                    navigator.startTracking()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Navigate") {
                    navigator.startNavigation()
                }
                .buttonStyle(.bordered)
                .disabled(!navigator.isTracking)
            }
            
            if let instruction = navigator.currentInstruction {
                Text(instruction)
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Simplified Anchor Implementation
class SimpleAnchor: NSObject, ObservableObject {
    @Published var isActive = false
    @Published var lastDistance: Float?
    
    private var niSession: NISession?
    private var mcSession: MCSession?
    private var mcAdvertiser: MCNearbyServiceAdvertiser?
    
    func start(id: String) {
        // Setup NI
        guard NISession.isSupported else {
            print("Device doesn't support Nearby Interaction")
            return
        }
        
        niSession = NISession()
        niSession?.delegate = self
        
        // Setup Multipeer
        let peerID = MCPeerID(displayName: "Anchor-\(id)")
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession?.delegate = self
        
        mcAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, 
                                                 discoveryInfo: ["type": "anchor", "id": id],
                                                 serviceType: "indoor-nav")
        mcAdvertiser?.delegate = self
        mcAdvertiser?.startAdvertisingPeer()
        
        isActive = true
    }
    
    func stop() {
        niSession?.invalidate()
        mcAdvertiser?.stopAdvertisingPeer()
        mcSession?.disconnect()
        isActive = false
        lastDistance = nil
    }
}

// MARK: - Simplified Navigator Implementation
class SimpleNavigator: NSObject, ObservableObject {
    @Published var isTracking = false
    @Published var currentPosition = CGPoint.zero
    @Published var currentInstruction: String?
    @Published var mapImage: UIImage?
    @Published var path: [CGPoint] = []
    
    private var arSession: ARSession?
    private var niSession: NISession?
    private var mcSession: MCSession?
    private var mcBrowser: MCNearbyServiceBrowser?
    
    func startTracking() {
        // Start AR
        arSession = ARSession()
        arSession?.delegate = self
        let config = ARWorldTrackingConfiguration()
        arSession?.run(config)
        
        // Start NI
        guard NISession.isSupported else {
            print("Device doesn't support Nearby Interaction")
            return
        }
        
        niSession = NISession()
        niSession?.delegate = self
        
        // Start browsing for anchors
        let peerID = MCPeerID(displayName: "Navigator-\(UUID().uuidString.prefix(4))")
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession?.delegate = self
        
        mcBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: "indoor-nav")
        mcBrowser?.delegate = self
        mcBrowser?.startBrowsingForPeers()
        
        isTracking = true
    }
    
    func startNavigation() {
        // Simple A* pathfinding would go here
        currentInstruction = "Navigation started - follow the blue path"
        
        // Demo path
        path = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 200, y: 100),
            CGPoint(x: 200, y: 200),
            CGPoint(x: 300, y: 200)
        ]
    }
}

// MARK: - Map Display
struct MapDisplayView: UIViewRepresentable {
    @ObservedObject var navigator: SimpleNavigator
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .systemGray6
        
        // Add map image view
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = navigator.mapImage
        view.addSubview(imageView)
        
        // Setup constraints
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update map display
    }
}

// MARK: - NISessionDelegate Extensions
extension SimpleAnchor: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        DispatchQueue.main.async {
            self.lastDistance = nearbyObjects.first?.distance
        }
    }
}

extension SimpleNavigator: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        // Update position based on NI
    }
}

// MARK: - ARSessionDelegate
extension SimpleNavigator: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Update position from AR
        DispatchQueue.main.async {
            // Simple position update
            let transform = frame.camera.transform
            self.currentPosition = CGPoint(x: Double(transform.columns.3.x),
                                          y: Double(transform.columns.3.z))
        }
    }
}

// MARK: - MCSessionDelegate
extension SimpleAnchor: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        if state == .connected {
            // Share NI token
            if let token = niSession?.discoveryToken {
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
                    try session.send(data, toPeers: [peerID], with: .reliable)
                } catch {
                    print("Failed to send token: \(error)")
                }
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Receive navigator's token and start NI session
        do {
            if let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
                let config = NINearbyPeerConfiguration(peerToken: token)
                niSession?.run(config)
            }
        } catch {
            print("Failed to receive token: \(error)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension SimpleNavigator: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        // Handle connection state
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Receive anchor's token
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension SimpleAnchor: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, mcSession)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate  
extension SimpleNavigator: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID, to: mcSession!, withContext: nil, timeout: 30)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}