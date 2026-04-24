import Foundation

private final class LockedDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        storage.append(data)
        lock.unlock()
    }
}

struct TrackerRunner: Sendable {
    enum RunnerError: LocalizedError {
        case missingTracker
        case invalidOutput(String)
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingTracker:
                "Could not find bundled progress_tracker.py. Rebuild the app with build-app.sh."
            case let .invalidOutput(message):
                "Could not parse tracker JSON: \(message)"
            case let .commandFailed(message):
                message
            }
        }
    }

    func run(repo: TrackedRepo) async throws -> TrackerResult {
        let root = try latexcopRoot()
        let output = try await runCommand(
            in: root,
            arguments: [
                "uv",
                "run",
                "progress_tracker.py",
                "--repo-dir",
                repo.repoDir,
                "--file-path",
                repo.filePath,
                "--start-date",
                repo.startDate,
                "--min-chars",
                String(repo.minChars),
                "--interval-days",
                String(repo.intervalDays),
                "--no-auto-pull",
                "--json",
            ]
        )

        do {
            return try JSONDecoder().decode(TrackerResult.self, from: Data(output.utf8))
        } catch {
            throw RunnerError.invalidOutput(error.localizedDescription)
        }
    }

    private func runCommand(in directory: URL, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = arguments
            process.currentDirectoryURL = directory
            process.environment = trackerEnvironment()

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            let outputBuffer = LockedDataBuffer()
            let errorBuffer = LockedDataBuffer()

            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                outputBuffer.append(handle.availableData)
            }
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                errorBuffer.append(handle.availableData)
            }

            process.terminationHandler = { process in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                outputBuffer.append(outputPipe.fileHandleForReading.readDataToEndOfFile())
                errorBuffer.append(errorPipe.fileHandleForReading.readDataToEndOfFile())

                let output = String(data: outputBuffer.data, encoding: .utf8) ?? ""
                let error = String(data: errorBuffer.data, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let message = error.isEmpty ? output : error
                    continuation.resume(
                        throwing: RunnerError.commandFailed(
                            message.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    )
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: RunnerError.commandFailed(error.localizedDescription))
            }
        }
    }

    private func trackerEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let venv = appSupport.appendingPathComponent("latexcop/venv", isDirectory: true)
        let defaultPath = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            NSString(string: "~/.local/bin").expandingTildeInPath,
            NSString(string: "~/.cargo/bin").expandingTildeInPath,
        ].joined(separator: ":")
        environment["UV_PROJECT_ENVIRONMENT"] = venv.path
        environment["PATH"] = [environment["PATH"], defaultPath]
            .compactMap { $0 }
            .joined(separator: ":")
        return environment
    }

    private func latexcopRoot() throws -> URL {
        if let bundledRoot = Bundle.main.resourceURL?.appendingPathComponent(
            "latexcop",
            isDirectory: true
        ), FileManager.default.fileExists(
            atPath: bundledRoot.appendingPathComponent("progress_tracker.py").path
        ) {
            return bundledRoot
        }

        if let envRoot = ProcessInfo.processInfo.environment["LATEXCOP_ROOT"] {
            let url = URL(fileURLWithPath: envRoot)
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("progress_tracker.py").path) {
                return url
            }
        }

        let starts = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            Bundle.main.bundleURL,
            Bundle.main.executableURL,
        ].compactMap { $0 }

        for start in starts {
            if let root = findTrackerRoot(from: start) {
                return root
            }
        }

        throw RunnerError.missingTracker
    }

    private func findTrackerRoot(from start: URL) -> URL? {
        var candidate = start.hasDirectoryPath ? start : start.deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(
                atPath: candidate.appendingPathComponent("progress_tracker.py").path
            ) {
                return candidate
            }
            let parent = candidate.deletingLastPathComponent()
            if parent.path == candidate.path {
                break
            }
            candidate = parent
        }
        return nil
    }
}
