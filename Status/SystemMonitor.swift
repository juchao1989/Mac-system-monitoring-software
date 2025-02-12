import Foundation
import Darwin

class SystemMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var networkUpload: Double = 0.0    // KB/s or MB/s
    @Published var networkDownload: Double = 0.0   // KB/s or MB/s
    @Published var networkUploadUnit: String = "k"
    @Published var networkDownloadUnit: String = "k"
    @Published var cpuDisplayThreshold: Double = 80.0  // CPU显示阈值
    @Published var usedMemory: Double = 0.0    // GB
    @Published var cacheMemory: Double = 0.0    // GB
    @Published var freeMemory: Double = 0.0     // GB
    
    private var timer: Timer?
    private var previousData: NetworkData?
    private let updateInterval: TimeInterval = 2.0 // 更新间隔调整为2秒
    
    struct NetworkData {
        var bytesIn: UInt64
        var bytesOut: UInt64
        var timestamp: Date
    }
    
    init() {
        updateTotalMemory()
        startMonitoring()
    }
    
    private func updateTotalMemory() {
        var stats = vm_statistics64_data_t()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { ptr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, ptr, &size)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = vm_kernel_page_size
            
            // 计算已使用内存（不包括缓存）
            let activeMemory = Double(UInt64(stats.active_count) * UInt64(pageSize))
            let wiredMemory = Double(UInt64(stats.wire_count) * UInt64(pageSize))
            usedMemory = (activeMemory + wiredMemory) / (1024 * 1024 * 1024) // Convert to GB
            
            // 计算缓存内存
            let inactiveMemory = Double(UInt64(stats.inactive_count) * UInt64(pageSize))
            let purgableMemory = Double(UInt64(stats.purgeable_count) * UInt64(pageSize))
            cacheMemory = (inactiveMemory + purgableMemory) / (1024 * 1024 * 1024) // Convert to GB
            
            // 计算空闲内存
            let freeCount = Double(UInt64(stats.free_count) * UInt64(pageSize))
            freeMemory = freeCount / (1024 * 1024 * 1024) // Convert to GB
        }
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateMetrics() {
        updateCPUUsage()
        updateNetworkUsage()
        updateTotalMemory()
    }
    
    private var previousCPUInfo: host_cpu_load_info?
    
    private func updateCPUUsage() {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            if let previous = previousCPUInfo {
                let user = Double(cpuInfo.cpu_ticks.0 - previous.cpu_ticks.0)
                let system = Double(cpuInfo.cpu_ticks.1 - previous.cpu_ticks.1)
                let idle = Double(cpuInfo.cpu_ticks.2 - previous.cpu_ticks.2)
                let nice = Double(cpuInfo.cpu_ticks.3 - previous.cpu_ticks.3)
                
                let total = user + system + idle + nice
                if total > 0 {
                    cpuUsage = ((user + system + nice) / total) * 100.0
                }
            }
            previousCPUInfo = cpuInfo
        }
    }
    

    private func updateNetworkUsage() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return }
        defer { freeifaddrs(ifaddr) }
        
        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        var validInterfaceFound = false
        var ptr = ifaddr
        
        // 只统计活跃的网络接口
        while ptr != nil {
            let addr = ptr!.pointee
            guard let name = String(cString: addr.ifa_name).nilIfEmpty else {
                ptr = addr.ifa_next
                continue
            }
            
            let flags = Int32(addr.ifa_flags)
            
            // 检查接口是否处于活跃状态且是以太网或Wi-Fi接口
            if (flags & IFF_UP) == IFF_UP && (flags & IFF_RUNNING) == IFF_RUNNING &&
               (name == "en0" || name == "en1" || name.hasPrefix("utun")) {
                if let data = addr.ifa_data?.assumingMemoryBound(to: if_data.self) {
                    let currentBytesIn = UInt64(data.pointee.ifi_ibytes)
                    let currentBytesOut = UInt64(data.pointee.ifi_obytes)
                    
                    // 检查数据有效性
                    if currentBytesIn > 0 || currentBytesOut > 0 {
                        bytesIn = currentBytesIn
                        bytesOut = currentBytesOut
                        validInterfaceFound = true
                        break // 找到有效接口后立即退出
                    }
                }
            }
            
            ptr = addr.ifa_next
        }
        
        // 如果没有找到有效接口，直接返回
        guard validInterfaceFound else { return }
        
        let currentData = NetworkData(bytesIn: bytesIn, bytesOut: bytesOut, timestamp: Date())
        
        if let previous = previousData {
            let timeInterval = currentData.timestamp.timeIntervalSince(previous.timestamp)
            
            // 确保时间间隔有效且不为零
            guard timeInterval > 0 else { return }
            
            // 检查是否发生计数器重置或溢出
            guard currentData.bytesIn >= previous.bytesIn && currentData.bytesOut >= previous.bytesOut else {
                previousData = currentData
                return
            }
            
            // 计算速率（字节/秒）并转换为KB/s
            let downloadSpeed = Double(currentData.bytesIn - previous.bytesIn) / timeInterval / 1024.0
            let uploadSpeed = Double(currentData.bytesOut - previous.bytesOut) / timeInterval / 1024.0
            
            // 防止异常值
            let validDownloadSpeed = max(0, min(downloadSpeed, 1000000))
            let validUploadSpeed = max(0, min(uploadSpeed, 1000000))
            
            // 自动转换单位（KB/s 到 MB/s）
            if validDownloadSpeed >= 1024.0 {
                networkDownload = validDownloadSpeed / 1024.0
                networkDownloadUnit = "m"
            } else {
                networkDownload = validDownloadSpeed
                networkDownloadUnit = "k"
            }
            
            if validUploadSpeed >= 1024.0 {
                networkUpload = validUploadSpeed / 1024.0
                networkUploadUnit = "m"
            } else {
                networkUpload = validUploadSpeed
                networkUploadUnit = "k"
            }
        }
        
        previousData = currentData
    }
}
