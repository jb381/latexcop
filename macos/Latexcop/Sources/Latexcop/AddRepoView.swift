import AppKit
import SwiftUI

struct AddRepoView: View {
    @EnvironmentObject private var model: AppModel
    let existingRepo: TrackedRepo?
    let onClose: () -> Void

    @State private var name: String
    @State private var repoDir: String
    @State private var filePath: String
    @State private var startDate: Date
    @State private var minChars: Int
    @State private var intervalDays: Int
    @State private var texFiles: [String] = []
    @State private var errorMessage: String?
    @State private var isValidating = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    init(existingRepo: TrackedRepo? = nil, onClose: @escaping () -> Void) {
        self.existingRepo = existingRepo
        self.onClose = onClose

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let parsedDate = existingRepo.flatMap { formatter.date(from: $0.startDate) } ?? Date()

        _name = State(initialValue: existingRepo?.name ?? "")
        _repoDir = State(initialValue: existingRepo?.repoDir ?? "")
        _filePath = State(initialValue: existingRepo?.filePath ?? "main.tex")
        _startDate = State(initialValue: parsedDate)
        _minChars = State(initialValue: existingRepo?.minChars ?? 1000)
        _intervalDays = State(initialValue: existingRepo?.intervalDays ?? 7)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existingRepo == nil ? "Add Repo" : "Edit Repo")
                .font(.system(.title2, design: .rounded, weight: .semibold))

            Form {
                TextField("Display name", text: $name)

                HStack {
                    TextField("Repo directory", text: $repoDir)
                    Button("Choose") {
                        chooseRepoDirectory()
                    }
                }

                if texFiles.isEmpty {
                    TextField("LaTeX file", text: $filePath)
                } else {
                    Picker("LaTeX file", selection: $filePath) {
                        ForEach(texFiles, id: \.self) { path in
                            Text(path).tag(path)
                        }
                    }
                    TextField("Custom file path", text: $filePath)
                }

                DatePicker("Start", selection: $startDate)


                Stepper("Minimum characters: \(minChars)", value: $minChars, in: 1...100_000)
                Stepper("Interval days: \(intervalDays)", value: $intervalDays, in: 1...365)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Cancel") {
                    onClose()
                }
                Spacer()
                Button {
                    Task {
                        await save()
                    }
                } label: {
                    if isValidating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(existingRepo == nil ? "Validate & Save" : "Validate & Update")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isValidating)
            }
        }
        .padding(20)
        .frame(width: 500)
        .background(.ultraThinMaterial)
        .onAppear {
            scanTexFiles()
        }
    }

    private func chooseRepoDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Repo"

        if panel.runModal() == .OK, let url = panel.url {
            repoDir = url.path
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                name = url.lastPathComponent
            }
            scanTexFiles()
        }
    }

    private func scanTexFiles() {
        let root = repoDir.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !root.isEmpty else {
            texFiles = []
            return
        }

        let rootURL = URL(fileURLWithPath: root, isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            texFiles = []
            return
        }

        var files: [String] = []
        for case let url as URL in enumerator {
            if url.pathComponents.contains(".git") {
                enumerator.skipDescendants()
                continue
            }
            guard url.pathExtension.lowercased() == "tex" else { continue }
            let relativePath = String(url.path.dropFirst(rootURL.path.count + 1))
            files.append(relativePath)
            if files.count >= 50 { break }
        }

        texFiles = files.sorted { lhs, rhs in
            if lhs == "main.tex" { return true }
            if rhs == "main.tex" { return false }
            return lhs < rhs
        }

        if !texFiles.isEmpty, !texFiles.contains(filePath) {
            filePath = texFiles[0]
        }
    }

    private func save() async {
        errorMessage = nil
        isValidating = true
        defer { isValidating = false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRepoDir = repoDir.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFilePath = filePath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "Add a display name."
            return
        }
        guard !trimmedRepoDir.isEmpty else {
            errorMessage = "Choose a repo directory."
            return
        }
        guard FileManager.default.fileExists(atPath: URL(fileURLWithPath: trimmedRepoDir).appendingPathComponent(".git").path) else {
            errorMessage = "Selected folder is not a Git repo."
            return
        }
        guard FileManager.default.fileExists(atPath: URL(fileURLWithPath: trimmedRepoDir).appendingPathComponent(trimmedFilePath).path) else {
            errorMessage = "Could not find \(trimmedFilePath) in the selected repo."
            return
        }

        let repo = TrackedRepo(
            id: existingRepo?.id ?? UUID(),
            name: trimmedName,
            repoDir: trimmedRepoDir,
            filePath: trimmedFilePath,
            startDate: dateFormatter.string(from: startDate),
            minChars: minChars,
            intervalDays: intervalDays
        )

        do {
            try await model.validate(repo: repo)
            if existingRepo == nil {
                try model.add(repo: repo)
            } else {
                try model.update(repo: repo)
            }
            onClose()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
