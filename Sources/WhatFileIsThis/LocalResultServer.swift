import Darwin
import Foundation

struct LocalResultPayload: Decodable {
    let pathB64: String
    let resultB64: String
}

/// A user-private, local-only hand-off channel for Shortcut results. It is a
/// Unix-domain socket rather than a result file: no analysis content is ever
/// persisted by the app.
final class LocalResultServer {
    static let socketPath = "/private/tmp/what-file-is-this-\(getuid()).sock"

    private let queue = DispatchQueue(label: "dev.is-a.zjy.whatfileisthis.result-server")
    private let onPayload: (LocalResultPayload) -> Void
    private var descriptor: Int32 = -1

    init(onPayload: @escaping (LocalResultPayload) -> Void) {
        self.onPayload = onPayload
    }

    func start() throws {
        guard descriptor < 0 else { return }
        try? FileManager.default.removeItem(atPath: Self.socketPath)

        let socketDescriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else { throw ServerError.unavailable }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let path = Array(Self.socketPath.utf8CString)
        guard path.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            close(socketDescriptor)
            throw ServerError.unavailable
        }

        withUnsafeMutableBytes(of: &address.sun_path) { destination in
            path.withUnsafeBytes { source in
                destination.copyBytes(from: source)
            }
        }

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketDescriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0, listen(socketDescriptor, 8) == 0 else {
            close(socketDescriptor)
            try? FileManager.default.removeItem(atPath: Self.socketPath)
            throw ServerError.unavailable
        }

        chmod(Self.socketPath, S_IRUSR | S_IWUSR)
        descriptor = socketDescriptor
        queue.async { [weak self, socketDescriptor] in
            self?.acceptConnections(on: socketDescriptor)
        }
    }

    func stop() {
        guard descriptor >= 0 else { return }
        shutdown(descriptor, SHUT_RDWR)
        close(descriptor)
        descriptor = -1
        try? FileManager.default.removeItem(atPath: Self.socketPath)
    }

    deinit {
        stop()
    }

    private func acceptConnections(on socketDescriptor: Int32) {
        while descriptor == socketDescriptor {
            let client = accept(socketDescriptor, nil, nil)
            guard client >= 0 else { break }
            readPayload(from: client)
        }
    }

    private func readPayload(from client: Int32) {
        defer { close(client) }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)

        while data.count < 2_000_000 {
            let count = buffer.withUnsafeMutableBufferPointer {
                recv(client, $0.baseAddress, $0.count, 0)
            }
            guard count > 0 else { break }
            data.append(contentsOf: buffer.prefix(Int(count)))
        }

        guard data.count < 2_000_000,
              let payload = try? JSONDecoder().decode(LocalResultPayload.self, from: data) else { return }
        DispatchQueue.main.async { [onPayload] in
            onPayload(payload)
        }
    }

    private enum ServerError: Error {
        case unavailable
    }
}
