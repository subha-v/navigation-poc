import Foundation
import NearbyInteraction

class NearbyInteractionAuthorization: NSObject {
    private var niSession: NISession?
    private var completion: ((Bool) -> Void)?
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        
        // Check if NI is supported on this device
        // Use new API for iOS 16+, fallback to deprecated for older versions
        if #available(iOS 16.0, *) {
            guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
                print("❌ Nearby Interaction is not supported on this device")
                completion(false)
                return
            }
        } else {
            guard NISession.isSupported else {
                print("❌ Nearby Interaction is not supported on this device")
                completion(false)
                return
            }
        }
        
        // Create a dummy NISession to trigger the permission prompt
        niSession = NISession()
        niSession?.delegate = self
        
        // Generate a discovery token to trigger permission
        // This will prompt for permission if not already granted
        if let token = niSession?.discoveryToken {
            print("✅ NI permission check initiated with token: \(token)")
            
            // The permission prompt appears when we access the discovery token
            // We'll get callbacks through the delegate if permission is granted
            
            // Wait a moment to see if delegate gets called
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                // If we got this far without errors, permission was likely granted
                print("✅ Nearby Interaction permission likely granted")
                completion(true)
                self?.cleanup()
            }
        } else {
            print("⚠️ Failed to generate NI token - permission may be denied")
            completion(false)
            cleanup()
        }
    }
    
    private func cleanup() {
        niSession?.invalidate()
        niSession = nil
        completion = nil
    }
}

extension NearbyInteractionAuthorization: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        // Won't receive updates in permission check
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        // Won't receive updates in permission check
    }
    
    func sessionWasSuspended(_ session: NISession) {
        print("⏸️ NI session suspended during permission check")
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        print("▶️ NI session resumed during permission check")
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        print("❌ NI session error during permission check: \(error)")
        
        // Check for permission-related errors
        let nsError = error as NSError
        if nsError.domain == "com.apple.NearbyInteraction" {
            switch nsError.code {
            case -5888: // User denied permission
                print("❌ User denied Nearby Interaction permission")
                completion?(false)
            case -5887: // Permission restricted
                print("❌ Nearby Interaction permission restricted")
                completion?(false)
            default:
                print("⚠️ NI error code: \(nsError.code)")
                // Might still have permission, just can't run without a peer
                completion?(true)
            }
        }
        
        cleanup()
    }
}