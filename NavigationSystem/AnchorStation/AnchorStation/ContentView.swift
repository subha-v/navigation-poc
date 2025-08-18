//
//  ContentView.swift
//  Anchor Station View
//

import SwiftUI
import NearbyInteraction
import MultipeerConnectivity

struct ContentView: View {
    @StateObject private var anchorManager = AnchorManager()
    @State private var anchorID = "anchor_A"
    @State private var anchorX = "0.0"
    @State private var anchorY = "0.0"
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Navigation Anchor")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Anchor Configuration
            GroupBox("Anchor Configuration") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Anchor ID:")
                        TextField("ID", text: $anchorID)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(anchorManager.isActive)
                    }
                    
                    HStack {
                        Text("Position X (m):")
                        TextField("X", text: $anchorX)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .disabled(anchorManager.isActive)
                    }
                    
                    HStack {
                        Text("Position Y (m):")
                        TextField("Y", text: $anchorY)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .disabled(anchorManager.isActive)
                    }
                }
                .padding()
            }
            
            // Status
            GroupBox("Status") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Circle()
                            .fill(anchorManager.isActive ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        Text(anchorManager.isActive ? "Active" : "Inactive")
                    }
                    
                    if let connectedPeer = anchorManager.connectedPeer {
                        Text("Connected to: \(connectedPeer)")
                            .font(.caption)
                    }
                    
                    if let distance = anchorManager.lastDistance {
                        Text(String(format: "Distance: %.2f m", distance))
                            .font(.headline)
                    }
                    
                    if let direction = anchorManager.lastDirection {
                        Text(String(format: "Direction: %.1f°", direction * 180 / .pi))
                            .font(.caption)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Control Button
            Button(action: {
                if anchorManager.isActive {
                    anchorManager.stop()
                } else {
                    if let x = Double(anchorX), let y = Double(anchorY) {
                        anchorManager.start(anchorID: anchorID, position: CGPoint(x: x, y: y))
                    }
                }
            }) {
                Text(anchorManager.isActive ? "Stop" : "Start")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 200, height: 50)
                    .background(anchorManager.isActive ? Color.red : Color.blue)
                    .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
}