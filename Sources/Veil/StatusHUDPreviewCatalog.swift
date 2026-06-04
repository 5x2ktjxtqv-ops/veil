import SwiftUI

#if DEBUG
struct StatusHUDPreviewCatalog: View {
    private let compactItems: [StatusHUDPreviewItem] = [
        StatusHUDPreviewItem(
            title: "Notch capsule VPN lane - 320 x 32",
            snapshot: PreviewFixtures.defaultCompact,
            configuration: .notchCapsule,
            fixedNotchLane: .vpn
        ),
        StatusHUDPreviewItem(
            title: "Default compact - 240 x 34",
            snapshot: PreviewFixtures.defaultCompact,
            configuration: .compact240
        ),
        StatusHUDPreviewItem(
            title: "Default roomy - 340 x 34",
            snapshot: PreviewFixtures.defaultCompact,
            configuration: .compact340
        ),
        StatusHUDPreviewItem(
            title: "VPN off - 340 x 34",
            snapshot: PreviewFixtures.vpnOff,
            configuration: .compact340
        ),
        StatusHUDPreviewItem(
            title: "Approval required - 340 x 34",
            snapshot: PreviewFixtures.approvalRequired,
            configuration: .compact340
        ),
        StatusHUDPreviewItem(
            title: "Memory elevated - 340 x 34",
            snapshot: PreviewFixtures.memoryElevated,
            configuration: .compact340
        ),
        StatusHUDPreviewItem(
            title: "Memory high - 340 x 34",
            snapshot: PreviewFixtures.memoryHigh,
            configuration: .compact340
        ),
        StatusHUDPreviewItem(
            title: "Latency degraded - 340 x 34",
            snapshot: PreviewFixtures.latencyDegraded,
            configuration: .compact340
        ),
        StatusHUDPreviewItem(
            title: "Network unknown - 340 x 34",
            snapshot: PreviewFixtures.networkUnknown,
            configuration: .compact340
        )
    ]

    private let expandedItems: [StatusHUDPreviewItem] = [
        StatusHUDPreviewItem(
            title: "Full expanded preview - 420 x 54",
            snapshot: PreviewFixtures.fullExpanded,
            configuration: .expanded420
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PreviewSection(title: "Compact default and priority states") {
                ForEach(compactItems) { item in
                    PreviewRow(item: item)
                }
            }

            PreviewSection(title: "Future expanded reference, not default") {
                ForEach(expandedItems) { item in
                    PreviewRow(item: item)
                }
            }
        }
        .padding(24)
        .background(Color(red: 0.07, green: 0.07, blue: 0.075))
    }
}

private struct StatusHUDPreviewItem: Identifiable {
    var title: String
    var snapshot: VeilSnapshot
    var configuration: StatusHUDConfiguration
    var fixedNotchLane: NotchCapsuleLaneID? = nil

    var id: String { title }
}

private struct PreviewSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.62))

            VStack(alignment: .leading, spacing: 10) {
                content
            }
        }
    }
}

private struct PreviewRow: View {
    var item: StatusHUDPreviewItem

    var body: some View {
        HStack(spacing: 18) {
            Text(item.title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.48))
                .frame(width: 250, alignment: .leading)

            StatusHUDSnapshotView(
                snapshot: item.snapshot,
                configuration: item.configuration,
                fixedNotchLane: item.fixedNotchLane
            )
        }
    }
}

struct StatusHUDPreviewCatalog_Previews: PreviewProvider {
    static var previews: some View {
        StatusHUDPreviewCatalog()
            .previewLayout(.sizeThatFits)
    }
}
#endif
