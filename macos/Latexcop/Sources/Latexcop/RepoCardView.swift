import SwiftUI

struct RepoCardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingWeeks = false

    let repo: TrackedRepo
    let status: RepoStatus
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name)
                        .font(.headline)
                    Text(repo.filePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
                cardActions
            }

            content

        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .idle:
            Text("Not refreshed yet")
                .foregroundStyle(.secondary)
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Refreshing")
                    .foregroundStyle(.secondary)
            }
        case let .failed(message):
            Text(message.isEmpty ? "Refresh failed" : message)
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        case let .loaded(result):
            if let period = result.currentPeriod {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(period.diffChars)")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                        Text("/ \(period.minChars) chars")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if period.commitCount > 0 {
                            Text("\(period.commitCount) commits")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    fullProgress(period: period)

                    HStack {
                        Text(period.targetMet ? "Goal met" : "\(period.remainingChars) remaining")
                        Spacer()
                        Text("Ends \(period.end)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    commitFreshness(result)
                        .padding(.vertical, 2)

                    Text("Weekly history")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    weekSparkline(records: result.records)
                    weekHistory(records: result.records)
                }
            } else {
                Text("No current period")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func weekHistory(records: [ProgressRecord]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    showingWeeks.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: showingWeeks ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .frame(width: 12)
                    Text("Weeks")
                        .font(.caption.weight(.semibold))
                    Text("\(records.count)")
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.14), in: Capsule())
                    Spacer()
                    Text("chars / commits")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showingWeeks {
                ForEach(records) { record in
                    HStack(spacing: 8) {
                        Text("W\(record.period)")
                            .font(.caption.weight(.semibold))
                            .frame(width: 24, alignment: .leading)

                        Circle()
                            .fill(record.isTargetMet ? .green : .orange)
                            .frame(width: 7, height: 7)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(shortWeekLabel(record))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            weekProgress(record: record)
                        }

                        Spacer(minLength: 8)

                        Text("\(record.diffChars) / \(record.commitCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(record.isTargetMet ? .primary : .secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func weekSparkline(records: [ProgressRecord]) -> some View {
        let visibleRecords = Array(records.suffix(16))
        let maxChars = max(visibleRecords.map(\.diffChars).max() ?? repo.minChars, repo.minChars, 1)

        return GeometryReader { proxy in
            let spacing: CGFloat = 5
            let count = max(CGFloat(visibleRecords.count), 1)
            let barWidth = max(10, (proxy.size.width - spacing * (count - 1)) / count)

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(visibleRecords) { record in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(record.isTargetMet ? Color.green.gradient : Color.orange.gradient)
                        .frame(
                            width: barWidth,
                            height: max(7, CGFloat(record.diffChars) / CGFloat(maxChars) * 38)
                        )
                        .overlay(alignment: .top) {
                            if record.isCurrent {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(.white.opacity(0.45), lineWidth: 1)
                            }
                        }
                        .help("Week \(record.period): \(record.diffChars) chars, \(record.commitCount) commits")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .padding(.top, 2)
        .frame(height: 42)
    }

    private func fullProgress(period: CurrentPeriod) -> some View {
        GeometryReader { proxy in
            let ratio = min(1, CGFloat(period.diffChars) / CGFloat(max(period.minChars, 1)))
            let visibleWidth = period.diffChars > 0 ? max(8, proxy.size.width * ratio) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.20))
                Capsule()
                    .fill(period.targetMet ? Color.green : Color.orange)
                    .frame(width: visibleWidth)
            }
        }
        .frame(height: 8)
    }

    private func weekProgress(record: ProgressRecord) -> some View {
        GeometryReader { proxy in
            let ratio = min(1, CGFloat(record.diffChars) / CGFloat(max(repo.minChars, 1)))
            let visibleWidth = record.diffChars > 0 ? max(6, proxy.size.width * ratio) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.16))
                Capsule()
                    .fill(record.isTargetMet ? Color.green : Color.orange)
                    .frame(width: visibleWidth)
            }
        }
        .frame(height: 5)
    }

    private func commitFreshness(_ result: TrackerResult) -> some View {
        HStack(spacing: 8) {
            if result.hasUncommittedChanges {
                Label("Uncommitted changes", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                    .help(result.warnings.first ?? "Uncommitted changes are included in the current diff.")
            }

            if let date = result.lastCommit.date {
                Label("Last commit \(relativeCommitDate(date))", systemImage: "clock")
                    .foregroundStyle(.secondary)
            } else {
                Label("No commits", systemImage: "clock.badge.questionmark")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private var cardActions: some View {
        Menu {
            Button("Edit", action: onEdit)
            Button("Open") {
                model.open(repo: repo)
            }
            Button("Remove", role: .destructive) {
                model.remove(repo: repo)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption.weight(.bold))
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Repo actions")
    }

    private func relativeCommitDate(_ value: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"

        guard let date = formatter.date(from: value) else {
            return value
        }

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }

    private func shortWeekLabel(_ record: ProgressRecord) -> String {
        if record.isCurrent {
            return "Current week"
        }

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd HH:mm"

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd"

        guard let start = parser.date(from: record.start),
              let end = parser.date(from: record.end) else {
            return "\(record.start) - \(record.end)"
        }

        return "\(formatter.string(from: start))-\(formatter.string(from: end))"
    }

    private var statusBadge: some View {
        let label: String
        let color: Color

        switch status {
        case let .loaded(result) where result.currentPeriod?.targetMet == true:
            label = "On track"
            color = .green
        case .loaded:
            label = "Behind"
            color = .orange
        case .failed:
            label = "Error"
            color = .red
        case .loading:
            label = "Loading"
            color = .blue
        case .idle:
            label = "Idle"
            color = .gray
        }

        return Text(label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }
}
