import Cocoa
import InputMethodKit
import WubiEngine
import WubiSupport

final class AppDelegate: NSObject, NSApplicationDelegate {
    var server: IMKServer?
    private let databasePathResolver = DatabasePathResolver()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            try databasePathResolver.createDatabaseDirectory()
        } catch {
            print("Failed to create database directory: \(error)")
            return
        }

        let dbPath = databasePathResolver.databasePath
        guard !FileManager.default.fileExists(atPath: dbPath) else {
            return
        }

        do {
            try WubiDictBuilder.buildSample(to: dbPath)
            print("Sample database created at: \(dbPath)")
        } catch {
            print("Failed to build sample database: \(error)")
        }
    }
}
