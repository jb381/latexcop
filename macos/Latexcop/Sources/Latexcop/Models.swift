import Foundation

struct AppConfig: Codable {
    var repos: [TrackedRepo] = []
}

struct TrackedRepo: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var repoDir: String
    var filePath: String = "main.tex"
    var startDate: String
    var minChars: Int = 1000
    var intervalDays: Int = 7

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case repoDir = "repo_dir"
        case filePath = "file_path"
        case startDate = "start_date"
        case minChars = "min_chars"
        case intervalDays = "interval_days"
    }
}

struct TrackerResult: Codable {
    var repoDir: String
    var filePath: String
    var minChars: Int
    var intervalDays: Int
    var currentPeriod: CurrentPeriod?
    var records: [ProgressRecord]
    var hasUncommittedChanges: Bool
    var lastCommit: LastCommit
    var warnings: [String]

    enum CodingKeys: String, CodingKey {
        case repoDir = "repo_dir"
        case filePath = "file_path"
        case minChars = "min_chars"
        case intervalDays = "interval_days"
        case currentPeriod = "current_period"
        case records
        case hasUncommittedChanges = "has_uncommitted_changes"
        case lastCommit = "last_commit"
        case warnings
    }
}

struct LastCommit: Codable {
    var hash: String?
    var date: String?
}

struct ProgressRecord: Codable, Identifiable {
    var period: Int
    var start: String
    var end: String
    var diffChars: Int
    var commitCount: Int
    var targetMet: String
    var locked: String

    var id: Int { period }

    var isTargetMet: Bool { targetMet == "Yes" }
    var isCurrent: Bool { locked.contains("Current") }

    enum CodingKeys: String, CodingKey {
        case period = "Period"
        case start = "Start"
        case end = "End"
        case diffChars = "DiffChars"
        case commitCount = "CommitCount"
        case targetMet = "TargetMet"
        case locked = "Locked"
    }
}

struct CurrentPeriod: Codable {
    var period: Int
    var start: String
    var end: String
    var diffChars: Int
    var commitCount: Int
    var minChars: Int
    var remainingChars: Int
    var targetMet: Bool
    var locked: Bool

    enum CodingKeys: String, CodingKey {
        case period
        case start
        case end
        case diffChars = "diff_chars"
        case commitCount = "commit_count"
        case minChars = "min_chars"
        case remainingChars = "remaining_chars"
        case targetMet = "target_met"
        case locked
    }
}

enum RepoStatus {
    case idle
    case loading
    case loaded(TrackerResult)
    case failed(String)

    var targetMet: Bool {
        if case let .loaded(result) = self {
            return result.currentPeriod?.targetMet ?? false
        }
        return false
    }
}
