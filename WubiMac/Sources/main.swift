// main.swift
// WubiMac — 入口点

import Cocoa
import InputMethodKit

// 1. 从 Info.plist 读取 IMK 连接名
guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String else {
    NSLog("WubiMac: InputMethodConnectionName not found in Info.plist")
    exit(1)
}

guard let bundleID = Bundle.main.bundleIdentifier else {
    NSLog("WubiMac: Bundle identifier is nil")
    exit(1)
}

// 2. 创建 IMKServer（系统通过此连接与输入法通信）
guard let server = IMKServer(name: connectionName, bundleIdentifier: bundleID) else {
    NSLog("WubiMac: Failed to create IMKServer with name: \(connectionName)")
    exit(1)
}

NSLog("WubiMac: IMKServer started — connection: \(connectionName), bundle: \(bundleID)")

// 3. 初始化 AppDelegate（负责码表数据库初始化）
let delegate = AppDelegate()
delegate.server = server
NSApplication.shared.delegate = delegate

// 4. 进入主事件循环
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
