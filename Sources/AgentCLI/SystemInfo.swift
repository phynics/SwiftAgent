//
//  SystemInfo.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/11.
//

import Foundation

/// Represents detailed system information needed for the agent
public struct SystemInfo: CustomStringConvertible {
    /// Operating system name
    public let osName: String
    
    /// Operating system version
    public let osVersion: String
    
    /// Operating system build version
    public let osBuild: String
    
    /// Default shell
    public let defaultShell: String
    
    /// Home directory path
    public let homeDirectory: String
    
    /// Current working directory
    public let currentWorkingDirectory: String
    
    /// Current date in yyyy-MM-dd format
    public let currentDate: String
    
    /// Current time in HH:mm:ss format
    public let currentTime: String
    
    /// Creates system information
    public init() {
        let processInfo = ProcessInfo.processInfo
        let osVersionString = processInfo.operatingSystemVersionString
        let defaultShell = processInfo.environment["SHELL"] ?? "/bin/bash"
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let currentDir = FileManager.default.currentDirectoryPath
        
        let userDir = FileManager.default.urls(for: .userDirectory, in: .userDomainMask).first?.path ?? "Unknown"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let now = Date()
        
        self.osName = SystemInfo.fetchOSName()
        self.osVersion = osVersionString.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        self.osBuild = osVersionString.components(separatedBy: "(").last?.trimmingCharacters(in: CharacterSet(charactersIn: "()")) ?? "Unknown"
        self.defaultShell = defaultShell
        self.homeDirectory = homeDir
        self.currentWorkingDirectory = currentDir
        self.currentDate = dateFormatter.string(from: now)
        self.currentTime = timeFormatter.string(from: now)
    }
    
    /// Creates system information with custom values (primarily for testing)
    public init(
        osName: String,
        osVersion: String,
        osBuild: String,
        defaultShell: String,
        homeDirectory: String,
        currentWorkingDirectory: String,
        userDirectory: String,
        currentDate: String,
        currentTime: String
    ) {
        self.osName = osName
        self.osVersion = osVersion
        self.osBuild = osBuild
        self.defaultShell = defaultShell
        self.homeDirectory = homeDirectory
        self.currentWorkingDirectory = currentWorkingDirectory
        self.currentDate = currentDate
        self.currentTime = currentTime
    }
    
    /// Provides a human-readable description of the system information
    public var description: String {
        """
        [SYSTEM INFORMATION]:
        Operating System: \(osName) \(osVersion) (Build \(osBuild))
        Default Shell: \(defaultShell)
        Home Directory: \(homeDirectory)
        Current Working Directory: \(currentWorkingDirectory)
        Current Date: \(currentDate)
        Current Time: \(currentTime)
        """
    }
    
    /// Fetches the operating system name dynamically using the `uname` command
    private static func fetchOSName() -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/uname")
        process.arguments = ["-s"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        } catch {
            return "Unknown"
        }
    }
}
