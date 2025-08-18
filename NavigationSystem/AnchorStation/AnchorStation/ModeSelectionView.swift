//
//  ModeSelectionView.swift
//  Mode selection screen for choosing between Anchor and Navigation modes
//

import SwiftUI

enum AppMode {
    case anchor
    case navigation
}

struct ModeSelectionView: View {
    @Binding var selectedMode: AppMode?
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Select Mode")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 60)
            
            Text("Choose how you want to use this device")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Anchor Mode Button
            Button(action: {
                selectedMode = .anchor
            }) {
                VStack(spacing: 15) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Anchor Mode")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Broadcast as a navigation anchor")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Navigation Mode Button
            Button(action: {
                selectedMode = .navigation
            }) {
                VStack(spacing: 15) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Navigation Mode")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Navigate to destinations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color.green.opacity(0.1))
                .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .padding(.horizontal, 30)
    }
}