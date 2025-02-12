//
//  StatusApp.swift
//  Status
//
//  Created by SuperJu on 2025/2/7.
//

import SwiftUI

@main
struct StatusApp: App {
    @StateObject private var monitor = SystemMonitor()
    
    var body: some Scene {
        MenuBarExtra {
            ContentView(monitor: monitor)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                if monitor.cpuUsage > monitor.cpuDisplayThreshold {
                    Text("CPU:\(String(format: "%.0f%%", monitor.cpuUsage))")
                        .font(.system(size: 10))
                } else {
                    Text("↓\(String(format: "%.0f %@", monitor.networkDownload,monitor.networkDownloadUnit))")
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
