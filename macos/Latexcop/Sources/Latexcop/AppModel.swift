import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var store = AppConfigStore()
    @Published var statuses: [UUID: RepoStatus] = [:]
    @Published var isRefreshing = false

    private let runner = TrackerRunner()

    var menuTitle: String {
        let total = store.config.repos.count
        guard total > 0 else { return "👮" }
        let met = store.config.repos.filter { statuses[$0.id]?.targetMet == true }.count
        return "👮 \(met)/\(total)"
    }

    func refreshAll() {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task {
            await withTaskGroup(of: (UUID, RepoStatus).self) { group in
                for repo in store.config.repos {
                    statuses[repo.id] = .loading
                    group.addTask {
                        do {
                            let result = try await self.runner.run(repo: repo)
                            return (repo.id, .loaded(result))
                        } catch {
                            return (repo.id, .failed(error.localizedDescription))
                        }
                    }
                }

                for await (id, status) in group {
                    statuses[id] = status
                    objectWillChange.send()
                }
            }
            isRefreshing = false
            objectWillChange.send()
        }
    }

    func validate(repo: TrackedRepo) async throws {
        _ = try await runner.run(repo: repo)
    }

    func add(repo: TrackedRepo) throws {
        try store.add(repo)
        statuses[repo.id] = .idle
        objectWillChange.send()
        refreshAll()
    }

    func update(repo: TrackedRepo) throws {
        try store.update(repo)
        statuses[repo.id] = .idle
        objectWillChange.send()
        refreshAll()
    }

    func remove(repo: TrackedRepo) {
        do {
            try store.remove(repo)
            statuses.removeValue(forKey: repo.id)
            objectWillChange.send()
        } catch {
            statuses[repo.id] = .failed(error.localizedDescription)
            objectWillChange.send()
        }
    }

    func open(repo: TrackedRepo) {
        NSWorkspace.shared.open(URL(fileURLWithPath: repo.repoDir, isDirectory: true))
    }
}
