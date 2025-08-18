//
//  NavigationView.swift
//  Main navigation interface
//

import SwiftUI
import MapKit

struct NavigationView: View {
    @StateObject private var navigationManager = NavigationManager()
    @State private var selectedDestination: POI?
    @State private var showDestinationPicker = false
    @State private var mapScale: CGFloat = 1.0
    @State private var mapOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            // Map display
            MapView(navigationManager: navigationManager,
                   scale: $mapScale,
                   offset: $mapOffset)
                .gesture(MagnificationGesture()
                    .onChanged { value in
                        mapScale = value
                    }
                )
                .gesture(DragGesture()
                    .onChanged { value in
                        mapOffset = value.translation
                    }
                )
            
            // UI Overlay
            VStack {
                // Top bar
                HStack {
                    // Status indicator
                    HStack {
                        Circle()
                            .fill(navigationManager.isLocalized ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        Text(navigationManager.isLocalized ? "Localized" : "Not Localized")
                            .font(.caption)
                        
                        Spacer()
                        
                        Text(navigationManager.trackingQuality)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(10)
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 15) {
                    // Current position
                    if navigationManager.isLocalized {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text(String(format: "Position: (%.1f, %.1f)",
                                       navigationManager.currentPosition.x,
                                       navigationManager.currentPosition.y))
                                .font(.caption)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(8)
                    }
                    
                    // Navigation info
                    if navigationManager.isNavigating {
                        VStack(spacing: 10) {
                            // Distance to destination
                            if let distance = navigationManager.distanceToDestination {
                                Text(String(format: "%.1f m to destination", distance))
                                    .font(.headline)
                            }
                            
                            // Next turn instruction
                            if let instruction = navigationManager.currentInstruction {
                                HStack {
                                    Image(systemName: instruction.icon)
                                        .font(.title)
                                    Text(instruction.text)
                                        .font(.body)
                                }
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    }
                    
                    // Action buttons
                    HStack(spacing: 20) {
                        // Initialize at anchor button
                        Button(action: {
                            navigationManager.showAnchorPicker = true
                        }) {
                            VStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("Init at Anchor")
                                    .font(.caption)
                            }
                            .frame(width: 80, height: 60)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        // Navigate button
                        Button(action: {
                            if navigationManager.isNavigating {
                                navigationManager.stopNavigation()
                            } else {
                                showDestinationPicker = true
                            }
                        }) {
                            VStack {
                                Image(systemName: navigationManager.isNavigating ? "stop.fill" : "location.north.fill")
                                Text(navigationManager.isNavigating ? "Stop" : "Navigate")
                                    .font(.caption)
                            }
                            .frame(width: 80, height: 60)
                            .background(navigationManager.isNavigating ? Color.red : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!navigationManager.isLocalized)
                        
                        // Center map button
                        Button(action: {
                            withAnimation {
                                mapScale = 1.0
                                mapOffset = .zero
                            }
                        }) {
                            VStack {
                                Image(systemName: "location.viewfinder")
                                Text("Center")
                                    .font(.caption)
                            }
                            .frame(width: 80, height: 60)
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                }
                .padding()
            }
        }
        .sheet(isPresented: $showDestinationPicker) {
            DestinationPicker(destinations: navigationManager.mapData?.pois ?? [],
                            selectedDestination: $selectedDestination,
                            onSelect: { destination in
                                navigationManager.startNavigation(to: destination)
                                showDestinationPicker = false
                            })
        }
        .sheet(isPresented: $navigationManager.showAnchorPicker) {
            AnchorPicker(anchors: navigationManager.mapData?.anchors ?? [],
                        onSelect: { anchor in
                            navigationManager.initializeAtAnchor(anchor)
                            navigationManager.showAnchorPicker = false
                        })
        }
        .onAppear {
            navigationManager.loadMap()
        }
    }
}

struct MapView: UIViewRepresentable {
    @ObservedObject var navigationManager: NavigationManager
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    
    func makeUIView(context: Context) -> UIView {
        return MapUIView(navigationManager: navigationManager)
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let mapView = uiView as? MapUIView else { return }
        mapView.updateDisplay()
    }
}

class MapUIView: UIView {
    private let navigationManager: NavigationManager
    private var imageView: UIImageView?
    private var pathLayer: CAShapeLayer?
    private var userLayer: CAShapeLayer?
    
    init(navigationManager: NavigationManager) {
        self.navigationManager = navigationManager
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        backgroundColor = .systemGray6
        
        // Add map image
        imageView = UIImageView()
        imageView?.contentMode = .scaleAspectFit
        if let mapData = navigationManager.mapData {
            imageView?.image = mapData.gridImage
        }
        
        if let imageView = imageView {
            addSubview(imageView)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
                imageView.topAnchor.constraint(equalTo: topAnchor),
                imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
        
        // Add path layer
        pathLayer = CAShapeLayer()
        pathLayer?.strokeColor = UIColor.systemBlue.cgColor
        pathLayer?.lineWidth = 3
        pathLayer?.fillColor = UIColor.clear.cgColor
        pathLayer?.lineCap = .round
        pathLayer?.lineJoin = .round
        layer.addSublayer(pathLayer!)
        
        // Add user position layer
        userLayer = CAShapeLayer()
        userLayer?.fillColor = UIColor.systemBlue.cgColor
        layer.addSublayer(userLayer!)
    }
    
    func updateDisplay() {
        // Update path
        if let path = navigationManager.currentPath,
           let mapData = navigationManager.mapData {
            let bezierPath = UIBezierPath()
            
            for (index, point) in path.enumerated() {
                let pixel = mapData.metersToPixel(point)
                let screenPoint = pixelToScreen(pixel)
                
                if index == 0 {
                    bezierPath.move(to: screenPoint)
                } else {
                    bezierPath.addLine(to: screenPoint)
                }
            }
            
            pathLayer?.path = bezierPath.cgPath
        } else {
            pathLayer?.path = nil
        }
        
        // Update user position
        if navigationManager.isLocalized,
           let mapData = navigationManager.mapData {
            let pixel = mapData.metersToPixel(navigationManager.currentPosition)
            let screenPoint = pixelToScreen(pixel)
            
            let circlePath = UIBezierPath(arcCenter: screenPoint,
                                         radius: 8,
                                         startAngle: 0,
                                         endAngle: .pi * 2,
                                         clockwise: true)
            
            // Add heading indicator
            let headingLength: CGFloat = 15
            let headingX = screenPoint.x + headingLength * cos(navigationManager.currentHeading - .pi/2)
            let headingY = screenPoint.y + headingLength * sin(navigationManager.currentHeading - .pi/2)
            
            circlePath.move(to: screenPoint)
            circlePath.addLine(to: CGPoint(x: headingX, y: headingY))
            
            userLayer?.path = circlePath.cgPath
        } else {
            userLayer?.path = nil
        }
    }
    
    private func pixelToScreen(_ pixel: CGPoint) -> CGPoint {
        guard let imageView = imageView,
              let image = imageView.image else { return pixel }
        
        let imageSize = image.size
        let viewSize = imageView.bounds.size
        
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        let scale = min(scaleX, scaleY)
        
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2
        
        return CGPoint(x: offsetX + pixel.x * scale,
                      y: offsetY + pixel.y * scale)
    }
}

struct DestinationPicker: View {
    let destinations: [POI]
    @Binding var selectedDestination: POI?
    let onSelect: (POI) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(destinations) { destination in
                Button(action: {
                    selectedDestination = destination
                    onSelect(destination)
                }) {
                    HStack {
                        Text(destination.name)
                        Spacer()
                        Text(String(format: "(%.1f, %.1f)", 
                                   destination.xy[0], destination.xy[1]))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Select Destination")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

struct AnchorPicker: View {
    let anchors: [Anchor]
    let onSelect: (Anchor) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(anchors) { anchor in
                Button(action: {
                    onSelect(anchor)
                }) {
                    HStack {
                        Text(anchor.id)
                        Spacer()
                        Text(String(format: "(%.1f, %.1f)",
                                   anchor.xy[0], anchor.xy[1]))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Initialize at Anchor")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

// Make POI and Anchor Identifiable
extension POI: Identifiable {}
extension Anchor: Identifiable {}