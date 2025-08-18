//
//  AnchorModeView.swift
//  Anchor mode - select anchor ID and broadcast
//

import SwiftUI

struct AnchorModeView: View {
    @StateObject private var anchorManager = AnchorManager()
    @State private var selectedAnchorID = ""
    @State private var isRunning = false
    @Binding var selectedMode: AppMode?
    
    // Predefined anchor positions (can be configured elsewhere)
    let predefinedAnchors = [
        ("Kitchen", CGPoint(x: 0, y: 0)),
        ("Living Room", CGPoint(x: 5, y: 0)),
        ("Bedroom", CGPoint(x: 5, y: 5)),
        ("Bathroom", CGPoint(x: 0, y: 5))
    ]
    
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
                    Text("Select Anchor Location")
                        .font(.headline)
                    
                    ForEach(predefinedAnchors, id: \.0) { anchor in
                        Button(action: {
                            selectedAnchorID = anchor.0
                            startAnchor(id: anchor.0, position: anchor.1)
                        }) {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text(anchor.0)
                                    .font(.title3)
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
                        .symbolEffect(.pulse)
                    
                    Text("Broadcasting as")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(selectedAnchorID)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
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
    
    private func startAnchor(id: String, position: CGPoint) {
        anchorManager.start(anchorID: id, position: position)
        isRunning = true
    }
}