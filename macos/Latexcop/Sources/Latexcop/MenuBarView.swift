import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("minimalMode") private var minimalMode = false

    let onAddRepo: () -> Void
    let onEditRepo: (TrackedRepo) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if model.store.config.repos.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.store.config.repos) { repo in
                            if minimalMode {
                                MinimalRepoRow(
                                    repo: repo,
                                    status: model.statuses[repo.id] ?? .idle,
                                    onEdit: { onEditRepo(repo) }
                                )
                            } else {
                                RepoCardView(
                                    repo: repo,
                                    status: model.statuses[repo.id] ?? .idle,
                                    onEdit: { onEditRepo(repo) }
                                )
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 16)
                }
                .frame(height: minimalMode ? nil : 420)
                .frame(maxHeight: minimalMode ? 260 : nil)
            }

            footer
        }
        .frame(width: 390)
        .fixedSize(horizontal: false, vertical: minimalMode)
        .background(.ultraThinMaterial)
        .task {
            model.refreshAll()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("latexcop")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Text("LaTeX progress across repos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            glassModeToggle

            Button {
                model.refreshAll()
            } label: {
                if model.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .disabled(model.isRefreshing)
            .help("Refresh")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var glassModeToggle: some View {
        HStack(spacing: 0) {
            modeButton(title: "Min", symbol: "rectangle.compress.vertical", tint: .green, isSelected: minimalMode) {
                setMinimalMode(true)
            }
            modeButton(title: "Full", symbol: "rectangle.expand.vertical", tint: .cyan, isSelected: !minimalMode) {
                setMinimalMode(false)
            }
        }
        .padding(3)
        .frame(width: 116, height: 30)
        .background(.thinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
    }

    private func modeButton(
        title: String,
        symbol: String,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.caption2.weight(.bold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(isSelected ? tint : .secondary)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(tint.opacity(0.18))
                            .background(.ultraThinMaterial, in: Capsule())
                            .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
                            .overlay {
                                Capsule()
                                    .strokeBorder(tint.opacity(0.35), lineWidth: 1)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
        .help(title == "Min" ? "Minimal view" : "Full view")
    }

    private func setMinimalMode(_ value: Bool) {
        withAnimation(.snappy(duration: 0.2)) {
            minimalMode = value
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No repos yet")
                .font(.headline)
            Text("Add a Git-backed LaTeX repo to start tracking current-period characters and commits.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var footer: some View {
        HStack {
            Button("Add Repo") {
                onAddRepo()
            }
            .buttonStyle(.borderedProminent)

            Button("Config") {
                model.store.openConfig()
            }

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(.thinMaterial)
    }
}
