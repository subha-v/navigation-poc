import Foundation
import Network

class LocalNetworkAuthorization: NSObject {
    private var browser: NWBrowser?
    private var netService: NetService?
    private var completion: ((Bool) -> Void)?
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        
        // Create a dummy NetService to trigger the permission prompt
        netService = NetService(domain: "local.", type: "_vnx._tcp.", name: "LocalNetworkPermissionCheck", port: 0)
        netService?.delegate = self
        netService?.publish()
        
        // Also create an NWBrowser as a backup trigger
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        browser = NWBrowser(for: .bonjour(type: "_vnx._tcp.", domain: nil), using: parameters)
        browser?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("✅ Local network access granted")
                completion(true)
            case .failed(let error):
                print("❌ Local network access denied: \(error)")
                completion(false)
            default:
                break
            }
        }
        
        browser?.start(queue: .main)
        
        // Timeout after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.cleanup()
        }
    }
    
    private func cleanup() {
        browser?.cancel()
        netService?.stop()
        browser = nil
        netService = nil
    }
}

extension LocalNetworkAuthorization: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        print("✅ NetService published - local network permission should be granted")
        completion?(true)
        cleanup()
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        print("❌ NetService failed to publish: \(errorDict)")
        if errorDict[NetService.errorCode] as? Int == NetService.ErrorCode.collisionError.rawValue {
            print("⚠️ Service name collision, but permission likely granted")
            completion?(true)
        } else {
            completion?(false)
        }
        cleanup()
    }
}