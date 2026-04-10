import Foundation

public final class StateStore {
    public let stateFileURL: URL

    private let fileManager: FileManager

    public init(
        stateFileURL: URL = BuoyPaths.stateFileURL(),
        fileManager: FileManager = .default
    ) {
        self.stateFileURL = stateFileURL
        self.fileManager = fileManager
    }

    public var stateDirectoryURL: URL {
        stateFileURL.deletingLastPathComponent()
    }

    public func load() throws -> PersistedState? {
        if fileManager.fileExists(atPath: stateFileURL.path) {
            let data = try Data(contentsOf: stateFileURL)
            return try JSONDecoder().decode(PersistedState.self, from: data)
        }

        return nil
    }

    public func save(_ state: PersistedState) throws {
        try fileManager.createDirectory(at: stateDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: stateFileURL, options: .atomic)
    }

    public func clear() throws {
        if fileManager.fileExists(atPath: stateFileURL.path) {
            try fileManager.removeItem(at: stateFileURL)
        }
    }
}
