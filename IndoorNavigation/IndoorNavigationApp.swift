//
//  IndoorNavigationApp.swift
//  Single app that can run as either Anchor or Navigator
//

import SwiftUI

@main
struct IndoorNavigationApp: App {
    @AppStorage("appMode") private var appMode = "navigator"
    
    var body: some Scene {
        WindowGroup {
            if appMode == "anchor" {
                AnchorModeView()
            } else {
                NavigatorModeView()
            }
        }
    }
}