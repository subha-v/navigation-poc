//
//  ContentView.swift
//  Main navigation view that coordinates between different modes
//

import SwiftUI

struct ContentView: View {
    @State private var selectedMode: AppMode?
    
    var body: some View {
        Group {
            if selectedMode == nil {
                ModeSelectionView(selectedMode: $selectedMode)
            } else if selectedMode == .anchor {
                AnchorModeView(selectedMode: $selectedMode)
            } else if selectedMode == .navigation {
                NavigationModeView(selectedMode: $selectedMode)
            }
        }
    }
}