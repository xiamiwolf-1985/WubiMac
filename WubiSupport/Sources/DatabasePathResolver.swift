import Foundation

public struct DatabasePathResolver {
    private let fileManager: FileManager
    private let applicationSupportURL: URL
    private let containerName: String
    private let databaseName: String

    public init(
        fileManager: FileManager = .default,
        applicationSupportURL: URL? = nil,
        containerName: String = "WubiMac",
        databaseName: String = "wubi86.db"
    ) {
        self.fileManager = fileManager
        self.applicationSupportURL = applicationSupportURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.containerName = containerName
        self.databaseName = databaseName
    }

    public var databaseDirectoryURL: URL {
        applicationSupportURL.appendingPathComponent(containerName, isDirectory: true)
    }

    public var databaseURL: URL {
        databaseDirectoryURL.appendingPathComponent(databaseName)
    }

    public var databasePath: String {
        databaseURL.path
    }

    public func createDatabaseDirectory() throws {
        try fileManager.createDirectory(at: databaseDirectoryURL, withIntermediateDirectories: true)
    }
}
