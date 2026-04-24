import SwiftUI

struct MinimalRepoRow: View {
    @EnvironmentObject private var model: AppModel

    let repo: TrackedRepo
    let status: RepoStatus
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(repo.filePath)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                statusPill
            }

            content
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu {
            Button("Edit", action: onEdit)
            Button("Open") {
                model.open(repo: repo)
            }
            Button("Remove", role: .destructive) {
                model.remove(repo: repo)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .idle:
            Text("Not refreshed")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Refreshing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case let .failed(message):
            Text(message.isEmpty ? "Refresh failed" : message)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
        case let .loaded(result):
            if let period = result.currentPeriod {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(period.diffChars)")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                        Text("/ \(period.minChars)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if result.hasUncommittedChanges {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                                .help("Uncommitted changes")
                        }

                        if period.commitCount > 0 {
                            Text("\(period.commitCount) commits")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    minimalProgress(period: period)

                    compactSparkline(records: result.records)
                }
            } else {
                Text("No current period")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func compactSparkline(records: [ProgressRecord]) -> some View {
        let visibleRecords = Array(records.suffix(12))
        let maxChars = max(visibleRecords.map(\.diffChars).max() ?? repo.minChars, repo.minChars, 1)

        return GeometryReader { proxy in
            let spacing: CGFloat = 4
            let count = max(CGFloat(visibleRecords.count), 1)
            let barWidth = max(8, (proxy.size.width - spacing * (count - 1)) / count)

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(visibleRecords) { record in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(record.isTargetMet ? Color.green.opacity(0.9) : Color.orange.opacity(0.9))
                        .frame(
                            width: barWidth,
                            height: max(4, CGFloat(record.diffChars) / CGFloat(maxChars) * 18)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(height: 20)
    }

    private func minimalProgress(period: CurrentPeriod) -> some View {
        GeometryReader { proxy in
            let ratio = min(1, CGFloat(period.diffChars) / CGFloat(max(period.minChars, 1)))
            let visibleWidth = period.diffChars > 0 ? max(6, proxy.size.width * ratio) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.18))
                Capsule()
                    .fill(period.targetMet ? Color.green : Color.accentColor)
                    .frame(width: visibleWidth)
            }
        }
        .frame(height: 7)
    }

    private var statusPill: some View {
        let label: String
        let color: Color

        switch status {
        case let .loaded(result) where result.currentPeriod?.targetMet == true:
            label = "OK"
            color = .green
        case .loaded:
            label = "Behind"
            color = .orange
        case .failed:
            label = "Error"
            color = .red
        case .loading:
            label = "..."
            color = .blue
        case .idle:
            label = "Idle"
            color = .gray
        }

        return Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }
}
