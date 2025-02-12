//
//  ContentView.swift
//  Status
//
//  Created by SuperJu on 2025/2/7.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "cpu")
                Text("CPU: \(String(format: "%.1f%%", monitor.cpuUsage))")
            }
            
            HStack {
                Image(systemName: "memorychip")
                VStack(alignment: .leading) {
                    Text("Used: \(String(format: "%.1f GB", monitor.usedMemory))")
                    Text("Cache: \(String(format: "%.1f GB", monitor.cacheMemory))")
                    Text("Free: \(String(format: "%.1f GB", monitor.freeMemory))")
                }
            }
            
            HStack {
                Image(systemName: "arrow.up.arrow.down")
                VStack(alignment: .leading) {
                    Text("↑: \(String(format: "%.1f %@", monitor.networkUpload,monitor.networkUploadUnit))")
                    Text("↓: \(String(format: "%.1f %@", monitor.networkDownload,monitor.networkDownloadUnit))")
                }
            }
            
            Divider()
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit")
                }
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(width: 200)
    }
}

#Preview {
    ContentView(monitor: SystemMonitor())
}
