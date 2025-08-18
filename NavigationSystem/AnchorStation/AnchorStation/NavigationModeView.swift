//
//  NavigationModeView.swift
//  Navigation mode - Find My style UI for navigation
//

import SwiftUI
import NearbyInteraction

struct NavigationModeView: View {
    @StateObject private var navigationManager = NavigationManager()
    @State private var selectedDestination = ""
    @State private var isNavigating = false
    @Binding var selectedMode: AppMode?
    
    let destinations = ["Kitchen", "Living Room", "Bedroom", "Bathroom"]
    
    var body: some View {
        VStack {
            // Header with back button
            HStack {
                Button(action: {
                    navigationManager.stop()
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
            
            if !isNavigating {
                // Destination selection
                VStack(spacing: 30) {
                    Text("Where do you want to go?")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.top, 40)
                    
                    VStack(spacing: 15) {
                        ForEach(destinations, id: \.self) { destination in
                            Button(action: {
                                selectedDestination = destination
                                startNavigation(to: destination)
                            }) {
                                HStack {
                                    Image(systemName: "location.fill")
                                    Text(destination)
                                        .font(.title3)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            } else {
                // Navigation UI - Find My style
                NavigationView(
                    destination: selectedDestination,
                    distance: navigationManager.currentDistance,
                    direction: navigationManager.currentDirection,
                    isConnected: navigationManager.isConnected,
                    onStop: {
                        navigationManager.stop()
                        isNavigating = false
                    }
                )
            }
        }
    }
    
    private func startNavigation(to destination: String) {
        navigationManager.startNavigation(to: destination)
        isNavigating = true
    }
}

// Find My style navigation view
struct NavigationView: View {
    let destination: String
    let distance: Float?
    let direction: Float?
    let isConnected: Bool
    let onStop: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Destination label
                VStack(spacing: 10) {
                    Text("Navigating to")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(destination)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Direction arrow
                if let direction = direction {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 120))
                        .foregroundColor(.blue)
                        .rotationEffect(.radians(Double(direction)))
                        .animation(.easeInOut(duration: 0.3), value: direction)
                } else {
                    Image(systemName: "location.circle")
                        .font(.system(size: 120))
                        .foregroundColor(.gray)
                }
                
                // Distance display
                if let distance = distance {
                    VStack(spacing: 5) {
                        Text(String(format: "%.1f", distance))
                            .font(.system(size: 60, weight: .bold))
                        Text("meters")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Searching...")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                
                // Connection status
                HStack {
                    Circle()
                        .fill(isConnected ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    Text(isConnected ? "Connected" : "Searching for anchors...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Stop button
                Button(action: onStop) {
                    Text("Stop Navigation")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.red)
                        .cornerRadius(25)
                }
                .padding(.bottom, 40)
            }
        }
    }
}