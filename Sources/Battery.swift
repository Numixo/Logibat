import Foundation
import IOKit.hid

struct BatteryReading: Codable {
    let id: String
    let name: String
    let kind: String
    let percent: Int
    let charging: Bool
    let approximate: Bool
}

struct ScanResult {
    var readings: [BatteryReading] = []
    var permissionDenied = false
    var interfaces = 0
}

// Only vendor HID++ reports are received. No key or pointer events are registered.
final class HIDChannel {
    let device: IOHIDDevice
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
    var response: [UInt8]?
    var expected: [UInt8] = []
    var opened = false
    var denied = false
    var sequence: UInt8 = 8

    init(_ device: IOHIDDevice) {
        self.device = device
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        denied = result == kIOReturnNotPermitted || result == kIOReturnNotPrivileged
        guard result == kIOReturnSuccess else { return }
        opened = true
        IOHIDDeviceRegisterInputReportCallback(device, buffer, 64, { context, result, _, _, _, report, length in
            guard let context, result == kIOReturnSuccess, length >= 4 else { return }
            let channel = Unmanaged<HIDChannel>.fromOpaque(context).takeUnretainedValue()
            let bytes = Array(UnsafeBufferPointer(start: report, count: length))
            if ProcessInfo.processInfo.arguments.contains("--trace") { print("RX", bytes.map { String(format: "%02X", $0) }.joined()) }
            guard channel.expected.count == 3, bytes[1] == channel.expected[0] else { return }
            if bytes[2] == channel.expected[1] && bytes[3] == channel.expected[2] {
                channel.response = bytes
            } else if bytes.count >= 6 && (bytes[2] == 0xFF || bytes[2] == 0x8F)
                        && bytes[3] == channel.expected[1] && bytes[4] == channel.expected[2] {
                channel.response = []
            }
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }

    deinit {
        if opened {
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        buffer.deallocate()
    }

    func query(_ slot: UInt8, _ feature: UInt8, _ function: UInt8 = 0, _ parameters: [UInt8] = []) -> [UInt8]? {
        guard opened else { return nil }
        // Alternate software IDs to reject late replies to an earlier request.
        sequence = sequence == 14 ? 8 : sequence + 1
        let command = function << 4 | sequence
        expected = [slot, feature, command]
        response = nil
        // USB receivers accept short requests; Bluetooth uses long requests.
        let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? ""
        let reportID: UInt8 = transport == "USB" ? 0x10 : 0x11
        let payloadSize = reportID == 0x10 ? 3 : 16
        let report: [UInt8] = [reportID, slot, feature, command] + parameters + Array(repeating: 0, count: payloadSize - parameters.count)
        let result = report.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(reportID), $0.baseAddress!, report.count)
        }
        if ProcessInfo.processInfo.arguments.contains("--trace") { print("TX", report.map { String(format: "%02X", $0) }.joined(), "result", result) }
        guard result == kIOReturnSuccess else { return nil }
        let end = Date().addingTimeInterval(2.5)
        while response == nil && Date() < end {
            CFRunLoopRunInMode(.defaultMode, 0.015, true)
        }
        guard let bytes = response, bytes.count >= 7 else { return nil }
        return Array(bytes.dropFirst(4))
    }

    func feature(_ slot: UInt8, _ id: UInt16) -> UInt8? {
        guard let answer = query(slot, 0, 0, [UInt8(id >> 8), UInt8(id & 255)]), answer[0] != 0 else { return nil }
        return answer[0]
    }

    func reading(_ slot: UInt8, identity: String, fallbackName: String) -> BatteryReading? {
        var percent: Int?
        var charging = false
        var approximate = false
        if let index = feature(slot, 0x1004), let info = query(slot, index, 1) {
            // Unified battery: state of charge, coarse level, charge status.
            if info[0] <= 100 {
                // A level-only device has no exact percentage capability.
                if let caps = query(slot, index), caps[1] & 2 == 0 { return nil }
                percent = Int(info[0])
                charging = info[2] == 1 || info[2] == 2
            }
        }
        if percent == nil, let index = feature(slot, 0x1000), let info = query(slot, index), info[0] <= 100 {
            percent = Int(info[0])
            charging = info[2] == 1 || info[2] == 2
            approximate = true
        }
        guard let percent else { return nil }
        var name = fallbackName
        var kind = name.lowercased().contains("key") ? "keyboard" : "mouse"
        if let index = feature(slot, 0x0005) {
            if let type = query(slot, index, 2) { kind = type[0] <= 1 ? "keyboard" : "mouse" }
            if let info = query(slot, index), info[0] > 0 {
                let length = min(Int(info[0]), 80)
                var bytes: [UInt8] = []
                while bytes.count < length {
                    guard let chunk = query(slot, index, 1, [UInt8(bytes.count)]) else { break }
                    bytes.append(contentsOf: chunk.prefix(length - bytes.count))
                }
                if bytes.count == length, let value = String(bytes: bytes, encoding: .utf8) { name = value }
            }
        }
        return BatteryReading(id: identity + ":\(slot)", name: name, kind: kind,
                              percent: percent, charging: charging, approximate: approximate)
    }
}

func scanBatteries() -> ScanResult {
    var result = ScanResult()
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x046D] as CFDictionary)
    guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return result }
    for device in devices {
        let page = (IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsagePageKey as CFString) as? NSNumber)?.intValue ?? 0
        let output = (IOHIDDeviceGetProperty(device, kIOHIDMaxOutputReportSizeKey as CFString) as? NSNumber)?.intValue ?? 0
        guard page >= 0xFF00, output >= 20 else { continue }
        result.interfaces += 1
        let channel = HIDChannel(device)
        result.permissionDenied = result.permissionDenied || channel.denied
        guard channel.opened else { continue }
        let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Logitech MX"
        let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? ""
        let service = IOHIDDeviceGetService(device)
        var entryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(service, &entryID)
        let receiver = name.lowercased().contains("receiver") || name.lowercased().contains("bolt")
        let slots: [UInt8] = receiver ? Array(1...6) + [0xFF] : [0xFF]
        for slot in slots {
            if let reading = channel.reading(slot, identity: "\(entryID)", fallbackName: name),
               !result.readings.contains(where: { $0.name == reading.name && $0.kind == reading.kind }) {
                result.readings.append(reading)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("--diagnose") {
            print("Interface: \(name), \(transport), pagina \(String(page, radix: 16)), open=\(channel.opened)")
        }
    }
    return result
}
