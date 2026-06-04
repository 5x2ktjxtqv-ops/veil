import AppKit
import Darwin

@main
struct VeilMain {
    @MainActor
    static func main() {
        #if DEBUG
        if let renderDirectory = HUDRenderExporter.outputDirectory(from: ProcessInfo.processInfo.arguments) {
            do {
                try HUDRenderExporter.exportAll(to: renderDirectory)
            } catch {
                fputs("Failed to export HUD renders: \(error)\n", stderr)
                exit(EXIT_FAILURE)
            }

            return
        }
        #endif

        let configuration = RuntimeConfiguration.load()
        if let startupError = configuration.startupError {
            fputs("\(startupError)\n", stderr)
            exit(EXIT_FAILURE)
        }

        switch PrivilegedRelauncher().relaunchIfNeeded(for: configuration) {
        case .notNeeded:
            break
        case .launched:
            exit(EXIT_SUCCESS)
        case .failed(let result):
            let output = result.output.isEmpty ? "\(result.termination)" : result.output
            fputs("Veil privileged relaunch failed: \(output)\n", stderr)
        }

        if let ownerProcessIdentifier = OverlayInstanceCoordinator.visibleOverlayOwnerProcessIdentifier(
            excluding: ProcessInfo.processInfo.processIdentifier
        ) {
            fputs("Veil overlay is already visible from pid \(ownerProcessIdentifier); this launch will not create a duplicate overlay.\n", stderr)
            exit(EXIT_SUCCESS)
        }

        let overlayInstanceLease: OverlayInstanceLease
        switch OverlayInstanceCoordinator.acquire() {
        case .success(let lease):
            overlayInstanceLease = lease
        case .failure(.alreadyRunning(let ownerProcessIdentifier)):
            let ownerDescription = ownerProcessIdentifier.map { " pid \($0)" } ?? ""
            fputs("Veil overlay is already running\(ownerDescription); this launch will not create a duplicate overlay.\n", stderr)
            exit(EXIT_SUCCESS)
        case .failure(let error):
            fputs("Failed to acquire Veil overlay ownership: \(error)\n", stderr)
            exit(EXIT_FAILURE)
        }

        let app = NSApplication.shared
        let delegate = AppDelegate(
            configuration: configuration,
            overlayInstanceLease: overlayInstanceLease
        )

        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
