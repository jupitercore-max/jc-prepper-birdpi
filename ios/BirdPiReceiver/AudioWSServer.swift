import Foundation
import Network

/// Tiny WebSocket server on top of Network.framework.
/// Accepts one BirdPi device, decodes RFC6455 frames, hands 16-bit PCM to `onAudio`.
/// UNTESTED ON DEVICE — minimal, no TLS, LAN only.
final class AudioWSServer {
    var onAudio: (([Int16]) -> Void)?

    private var listener: NWListener?
    private var connections: [NWConnection] = []

    init(port: UInt16) {
        let params = NWParameters(tcp: .init())
        params.allowLocalEndpointReuse = true
        listener = try? NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
    }

    func start() {
        listener?.newConnectionHandler = { [weak self] conn in
            self?.connections.append(conn)
            conn.start(queue: .global(qos: .userInitiated))
            self?.receiveLoop(conn)
        }
        listener?.start(queue: .global(qos: .userInitiated))
    }

    private func receiveLoop(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 2, maximumLength: 64 * 1024) { [weak self] data, _, done, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.handleRaw(conn, data)
            }
            if done || error != nil {
                conn.cancel()
                return
            }
            self.receiveLoop(conn)
        }
    }

    /// Extremely small RFC6455 subset: accepts masked client frames, ignores control frames.
    private func handleRaw(_ conn: NWConnection, _ data: Data) {
        guard data.count >= 2 else { return }
        let bytes = [UInt8](data)
        let opcode = bytes[0] & 0x0F
        var offset = 2
        let masked = (bytes[1] & 0x80) != 0
        var payloadLen = Int(bytes[1] & 0x7F)
        if payloadLen == 126 {
            guard data.count >= 4 else { return }
            payloadLen = Int(bytes[2]) << 8 | Int(bytes[3])
            offset = 4
        } else if payloadLen == 127 {
            guard data.count >= 10 else { return }
            payloadLen = Int(bytes[6]) << 24 | Int(bytes[7]) << 16 | Int(bytes[8]) << 8 | Int(bytes[9])
            offset = 10
        }
        var mask: [UInt8] = []
        if masked {
            guard data.count >= offset + 4 else { return }
            mask = Array(bytes[offset..<(offset + 4)])
            offset += 4
        }
        guard data.count >= offset + payloadLen else { return }
        var payload = Array(bytes[offset..<(offset + payloadLen)])
        if masked {
            for i in 0..<payload.count { payload[i] ^= mask[i % 4] }
        }
        switch opcode {
        case 0x1: // text
            // Accept (and ignore) the firmware's JSON status pings; reply with a pong frame
            if let str = String(bytes: payload, encoding: .utf8), str.contains("status") {
                conn.send(content: Data([0x8A, 0x00]), completion: .contentProcessed { _ in })
            }
        case 0x2: // binary — PCM16LE @ 16 kHz
            let pcm = payload.withUnsafeBytes { raw in
                Array(raw.bindMemory(to: Int16.self))
            }
            onAudio?(pcm)
        case 0x8: // close
            conn.cancel()
        default:
            break
        }
        // NOTE: this parser assumes one frame per receive() call, which matches the
        // firmware's 1024-byte frame cadence on a LAN. Not a general-purpose WS server.
    }
}
