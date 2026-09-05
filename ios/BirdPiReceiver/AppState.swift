import Foundation
import Combine

/// Shared app state: connection status, latest detections, settings.
final class AppState: ObservableObject {
    @Published var isServerRunning = false
    @Published var framesReceived: UInt64 = 0
    @Published var detections: [Detection] = []
    @Published var phoneIP: String = ""

    struct Detection: Identifiable, Equatable {
        let id = UUID()
        let species: String
        let confidence: Double
        let date: Date
    }

    private var server: AudioWSServer?
    private var classifier: SoundClassifier?

    init() {
        phoneIP = Self.localIPAddress() ?? "no WiFi"
        classifier = SoundClassifier()  // Sound Analysis; swap for BirdNetClassifier if you add a CoreML model
    }

    func start() {
        guard server == nil else { return }
        let s = AudioWSServer(port: 8765)
        s.onAudio = { [weak self] pcm in
            self?.framesReceived += UInt64(pcm.count)
            self?.classifier?.analyze(pcm) { species, conf in
                DispatchQueue.main.async {
                    self?.detections.insert(
                        .init(species: species, confidence: conf, date: Date()),
                        at: 0)
                    if self!.detections.count > 200 { self?.detections.removeLast() }
                }
            }
        }
        s.start()
        server = s
        isServerRunning = true
    }

    static func localIPAddress() -> String? {
        var addr: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        while let p = ptr {
            let iface = p.pointee
            if let sa = iface.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: iface.ifa_name)
                if name == "en0" {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count),
                                   nil, 0, NI_NUMERICHOST) == 0 {
                        addr = String(cString: host)
                    }
                }
            }
            ptr = iface.ifa_next
        }
        return addr
    }
}
