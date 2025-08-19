//
//  AnchorModeView.swift
//  Anchor mode - select anchor ID and broadcast
//

import SwiftUI

struct AnchorModeView: View {
    @StateObject private var anchorManager = AnchorManager()
    @State private var selectedAnchorID = ""
    @State private var selectedAnchorData: AnchorData?
    @State private var isRunning = false
    @Binding var selectedMode: AppMode?
    
    // Get anchor positions from configuration
    let anchorConfig = AnchorConfiguration.shared
    
    var body: some View {
        VStack(spacing: 30) {
            // Header with back button
            HStack {
                Button(action: {
                    anchorManager.stop()
                    selectedMode = nil
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
            
            Text("Anchor Mode")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if !isRunning {
                // Anchor selection
                VStack(spacing: 20) {
                    Text("Select Anchor Station")
                        .font(.headline)
                    
                    ForEach(anchorConfig.anchors, id: \.id) { anchor in
                        Button(action: {
                            selectedAnchorID = anchor.id
                            selectedAnchorData = anchor
                            startAnchor(anchorData: anchor)
                        }) {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                VStack(alignment: .leading) {
                                    Text(anchor.displayName)
                                        .font(.title3)
                                    Text("Position: (\(String(format: "%.1f", anchor.position.x)), \(String(format: "%.1f", anchor.position.y)))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            } else {
                // Running state - minimal UI
                VStack(spacing: 30) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Broadcasting as")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(selectedAnchorData?.displayName ?? selectedAnchorID)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if let position = selectedAnchorData?.position {
                        Text("Position: (\(String(format: "%.1f", position.x)), \(String(format: "%.1f", position.y)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let connectedPeer = anchorManager.connectedPeer {
                        Text("Connected: \(connectedPeer)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    Button(action: {
                        anchorManager.stop()
                        isRunning = false
                    }) {
                        Text("Stop Broadcasting")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
            
            Spacer()
        }
    }
    
    private func startAnchor(anchorData: AnchorData) {
        anchorManager.start(anchorID: anchorData.id, position: anchorData.position)
        isRunning = true
    }
}