import AppKit
import Foundation

@MainActor
final class AppConfigStore: ObservableObject {
    @Published private(set) var config = AppConfig()

    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()
    private let configURL: URL

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let directory = appSupport.appendingPathComponent("latexcop", isDirectory: true)
        configURL = directory.appendingPathComponent("config.json")
        load()
    }

    func add(_ repo: TrackedRepo) throws {
        config.repos.append(repo)
        try save()
    }

    func update(_ repo: TrackedRepo) throws {
        guard let index = config.repos.firstIndex(where: { $0.id == repo.id }) else {
            return
        }
        config.repos[index] = repo
        try save()
    }

    func remove(_ repo: TrackedRepo) throws {
        config.repos.removeAll { $0.id == repo.id }
        try save()
    }

    func openConfig() {
        NSWorkspace.shared.activateFileViewerSelecting([configURL])
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            config = AppConfig()
            return
        }

        do {
            let data = try Data(contentsOf: configURL)
            config = try decoder.decode(AppConfig.self, from: data)
        } catch {
            config = AppConfig()
        }
    }

    private func save() throws {
        let directory = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
    }
}
