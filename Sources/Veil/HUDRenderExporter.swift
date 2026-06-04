import AppKit
import Foundation
import SwiftUI

#if DEBUG
enum HUDRenderExporter {
    private static let argumentName = "--export-hud-renders"

    private struct RenderItem {
        var filename: String
        var snapshot: VeilSnapshot
        var configuration: StatusHUDConfiguration
        var fixedNotchLane: NotchCapsuleLaneID? = nil
    }

    private struct NotchCandidate {
        var title: String
        var style: NotchIslandStyle
    }

    static func outputDirectory(from arguments: [String]) -> URL? {
        guard let argumentIndex = arguments.firstIndex(of: argumentName) else { return nil }
        let pathIndex = arguments.index(after: argumentIndex)

        guard pathIndex < arguments.endIndex else {
            return URL(fileURLWithPath: "docs/design/renders")
        }

        let path = arguments[pathIndex]
        return URL(
            fileURLWithPath: path,
            relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        )
        .standardizedFileURL
    }

    @MainActor
    static func exportAll(to directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        for item in renderItems {
            let outputURL = directory.appendingPathComponent(item.filename)
            let data = try pngData(for: item)
            try data.write(to: outputURL, options: .atomic)
            print("Exported \(outputURL.path)")
        }

        let candidateURL = directory.appendingPathComponent("notch-capsule-candidates.png")
        let candidateData = try notchCandidateSheetPNGData()
        try candidateData.write(to: candidateURL, options: .atomic)
        print("Exported \(candidateURL.path)")
    }

    private static var renderItems: [RenderItem] {
        [
            RenderItem(
                filename: "notch-capsule.png",
                snapshot: PreviewFixtures.defaultCompact,
                configuration: .notchCapsule,
                fixedNotchLane: .vpn
            ),
            RenderItem(
                filename: "notch-capsule-vpn.png",
                snapshot: PreviewFixtures.defaultCompact,
                configuration: .notchCapsule,
                fixedNotchLane: .vpn
            ),
            RenderItem(
                filename: "notch-capsule-model-growth-workload.png",
                snapshot: PreviewFixtures.modelGrowthCompact,
                configuration: .notchCapsule,
                fixedNotchLane: .modelGrowthWorkload
            ),
            RenderItem(
                filename: "default-compact-240.png",
                snapshot: PreviewFixtures.defaultCompact,
                configuration: .compact240
            ),
            RenderItem(
                filename: "default-roomy-340.png",
                snapshot: PreviewFixtures.defaultCompact,
                configuration: .compact340
            ),
            RenderItem(
                filename: "full-expanded-420.png",
                snapshot: PreviewFixtures.fullExpanded,
                configuration: .expanded420
            ),
            RenderItem(
                filename: "vpn-off.png",
                snapshot: PreviewFixtures.vpnOff,
                configuration: .compact340
            ),
            RenderItem(
                filename: "approval-required.png",
                snapshot: PreviewFixtures.approvalRequired,
                configuration: .compact340
            ),
            RenderItem(
                filename: "memory-elevated.png",
                snapshot: PreviewFixtures.memoryElevated,
                configuration: .compact340
            ),
            RenderItem(
                filename: "memory-high.png",
                snapshot: PreviewFixtures.memoryHigh,
                configuration: .compact340
            ),
            RenderItem(
                filename: "latency-degraded.png",
                snapshot: PreviewFixtures.latencyDegraded,
                configuration: .compact340
            ),
            RenderItem(
                filename: "network-unknown.png",
                snapshot: PreviewFixtures.networkUnknown,
                configuration: .compact340
            )
        ]
    }

    private static var notchCandidates: [NotchCandidate] {
        [
            NotchCandidate(
                title: "current official-fit 4.5x5.5 continuous 14x9 c0.78",
                style: .nativeSoft
            ),
            NotchCandidate(
                title: "previous precise 5x6 continuous 18x12 c0.86",
                style: NotchIslandStyle(
                    screenInsetWidth: 30,
                    screenCornerWidth: 5,
                    screenCornerHeight: 6,
                    screenCornerControl: 0.54,
                    bottomCornerWidth: 18,
                    bottomCornerHeight: 12,
                    bottomCornerControl: 0.86
                )
            ),
            NotchCandidate(
                title: "tight native 4x5 continuous 12x8 c0.76",
                style: NotchIslandStyle(
                    screenInsetWidth: 30,
                    screenCornerWidth: 4,
                    screenCornerHeight: 5,
                    screenCornerControl: 0.50,
                    bottomCornerWidth: 12,
                    bottomCornerHeight: 8,
                    bottomCornerControl: 0.76
                )
            ),
            NotchCandidate(
                title: "raw official hard 3x4 continuous 6x5 c0.65",
                style: NotchIslandStyle(
                    screenInsetWidth: 30,
                    screenCornerWidth: 3,
                    screenCornerHeight: 4,
                    screenCornerControl: 0.50,
                    bottomCornerWidth: 6,
                    bottomCornerHeight: 5,
                    bottomCornerControl: 0.65
                )
            )
        ]
    }

    @MainActor
    private static func pngData(for item: RenderItem) throws -> Data {
        let view = StatusHUDSnapshotView(
            snapshot: item.snapshot,
            configuration: item.configuration,
            fixedNotchLane: item.fixedNotchLane
        )

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(
            width: item.configuration.width,
            height: item.configuration.height
        )

        guard let cgImage = renderer.cgImage else {
            throw RenderError.imageUnavailable(item.filename)
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw RenderError.pngEncodingFailed(item.filename)
        }

        return data
    }

    @MainActor
    private static func notchCandidateSheetPNGData() throws -> Data {
        let view = VStack(alignment: .leading, spacing: 14) {
            ForEach(notchCandidates.indices, id: \.self) { index in
                let candidate = notchCandidates[index]
                let configuration = StatusHUDConfiguration.notchCapsule.withNotchStyle(candidate.style)

                HStack(spacing: 14) {
                    Text(candidate.title)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.black.opacity(0.68))
                        .frame(width: 190, alignment: .leading)

                    StatusHUDSnapshotView(
                        snapshot: PreviewFixtures.defaultCompact,
                        configuration: configuration,
                        fixedNotchLane: .vpn
                    )
                    .background(Color(red: 0.78, green: 0.78, blue: 0.80))
                    .border(Color.black.opacity(0.12), width: 1)
                }
            }
        }
        .padding(18)
        .background(Color(red: 0.86, green: 0.86, blue: 0.88))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: 536, height: 232)

        guard let cgImage = renderer.cgImage else {
            throw RenderError.imageUnavailable("notch-capsule-candidates.png")
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw RenderError.pngEncodingFailed("notch-capsule-candidates.png")
        }

        return data
    }
}

private extension StatusHUDConfiguration {
    func withNotchStyle(_ style: NotchIslandStyle) -> StatusHUDConfiguration {
        var configuration = self
        configuration.notchStyle = style
        return configuration
    }
}

private enum RenderError: Error, CustomStringConvertible {
    case imageUnavailable(String)
    case pngEncodingFailed(String)

    var description: String {
        switch self {
        case .imageUnavailable(let filename):
            return "SwiftUI could not render \(filename)"
        case .pngEncodingFailed(let filename):
            return "AppKit could not encode \(filename) as PNG"
        }
    }
}
#endif
