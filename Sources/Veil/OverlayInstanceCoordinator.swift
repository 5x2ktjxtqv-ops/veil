import Darwin
import CoreGraphics
import Foundation

final class OverlayInstanceLease: @unchecked Sendable {
    private let lock = NSLock()
    private var fileDescriptor: CInt?

    let lockURL: URL

    init(fileDescriptor: CInt, lockURL: URL) {
        self.fileDescriptor = fileDescriptor
        self.lockURL = lockURL
    }

    deinit {
        invalidate()
    }

    func invalidate() {
        lock.lock()
        guard let fileDescriptor else {
            lock.unlock()
            return
        }

        self.fileDescriptor = nil
        lock.unlock()

        _ = flock(fileDescriptor, LOCK_UN)
        close(fileDescriptor)
    }
}

enum OverlayInstanceAcquireError: Error, Equatable {
    case alreadyRunning(ownerProcessIdentifier: pid_t?)
    case failedToOpenLock(errnoCode: Int32)
    case failedToLock(errnoCode: Int32)
}

enum OverlayInstanceCoordinator {
    static var defaultLockURL: URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dev.veil.overlay.\(getuid()).lock")
    }

    static func acquire(
        lockURL: URL = defaultLockURL,
        processIdentifier: pid_t = ProcessInfo.processInfo.processIdentifier
    ) -> Result<OverlayInstanceLease, OverlayInstanceAcquireError> {
        let fileDescriptor = open(lockURL.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        guard fileDescriptor >= 0 else {
            return .failure(.failedToOpenLock(errnoCode: errno))
        }

        if flock(fileDescriptor, LOCK_EX | LOCK_NB) != 0 {
            let lockErrno = errno
            let ownerProcessIdentifier = readOwnerProcessIdentifier(from: lockURL)
            close(fileDescriptor)

            if lockErrno == EWOULDBLOCK {
                return .failure(.alreadyRunning(ownerProcessIdentifier: ownerProcessIdentifier))
            }

            return .failure(.failedToLock(errnoCode: lockErrno))
        }

        writeOwnerProcessIdentifier(processIdentifier, to: fileDescriptor)
        return .success(OverlayInstanceLease(fileDescriptor: fileDescriptor, lockURL: lockURL))
    }

    static func visibleOverlayOwnerProcessIdentifier(excluding ownProcessIdentifier: pid_t) -> pid_t? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for window in windows {
            guard
                let ownerName = window[kCGWindowOwnerName as String] as? String,
                ownerName == "Veil",
                let ownerProcessIdentifier = window[kCGWindowOwnerPID as String] as? NSNumber,
                ownerProcessIdentifier.int32Value != ownProcessIdentifier,
                let alpha = window[kCGWindowAlpha as String] as? NSNumber,
                alpha.doubleValue > 0,
                let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
                bounds.width > 0,
                bounds.height > 0
            else {
                continue
            }

            return ownerProcessIdentifier.int32Value
        }

        return nil
    }

    private static func readOwnerProcessIdentifier(from lockURL: URL) -> pid_t? {
        guard let data = try? Data(contentsOf: lockURL),
              let contents = String(data: data, encoding: .utf8),
              let value = contents
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "\n")
                .first,
              let parsed = Int32(value) else {
            return nil
        }

        return parsed
    }

    private static func writeOwnerProcessIdentifier(_ processIdentifier: pid_t, to fileDescriptor: CInt) {
        ftruncate(fileDescriptor, 0)
        lseek(fileDescriptor, 0, SEEK_SET)

        let payload = "\(processIdentifier)\n"
        payload.withCString { pointer in
            _ = write(fileDescriptor, pointer, strlen(pointer))
        }
    }
}
