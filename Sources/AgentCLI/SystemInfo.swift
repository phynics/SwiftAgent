//
//  SystemInfo.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/11.
//

import Foundation

/// Represents system information needed for the agent
public struct SystemInfo {
    /// Operating system name
    public let osName: String
    
    /// Default shell
    public let defaultShell: String
    
    /// Home directory path
    public let homeDirectory: String
    
    /// Current date in yyyy-MM-dd format
    public let currentDate: String
    
    /// Current time in HH:mm:ss format
    public let currentTime: String
    
    /// Creates system information
    public init() {
        let processInfo = ProcessInfo.processInfo
        let defaultShell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/bash"
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let now = Date()
        
        self.osName = processInfo.operatingSystemVersionString
        self.defaultShell = defaultShell
        self.homeDirectory = homeDir
        self.currentDate = dateFormatter.string(from: now)
        self.currentTime = timeFormatter.string(from: now)
    }
    
    /// Creates system information with custom values (primarily for testing)
    public init(
        osName: String,
        defaultShell: String,
        homeDirectory: String,
        currentDate: String,
        currentTime: String
    ) {
        self.osName = osName
        self.defaultShell = defaultShell
        self.homeDirectory = homeDirectory
        self.currentDate = currentDate
        self.currentTime = currentTime
    }
}
