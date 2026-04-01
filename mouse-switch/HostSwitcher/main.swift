import AppKit
import Carbon.HIToolbox
import IOKit.hid

// MARK: - Logging

let logFile = NSHomeDirectory() + "/workspace/dotfiles/mouse-switch/hostswitcher.log"

func log(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    if let handle = FileHandle(forWritingAtPath: logFile) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: logFile, contents: line.data(using: .utf8))
    }
}

// MARK: - HID++ Protocol

private let LOGITECH_VID: Int32 = 0x046D
private let KNOWN_PIDS: Set<Int32> = [
    0xB023, 0xB028, 0xB034, // MX Master 3 variants
    0xB35B, 0xB35F, 0xB361, // MX Keys variants
]

private let HIDPP_LONG_REPORT_ID: UInt8 = 0x11
private let HIDPP_LONG_LEN = 20
private let BT_DEVICE_INDEX: UInt8 = 0xFF
private let SW_ID: UInt8 = 0x01
private let CHANGE_HOST_FEATURE: UInt16 = 0x1814

// MARK: - HID Manager

class HIDDeviceManager {
    static let shared = HIDDeviceManager()

    private let manager: IOHIDManager
    private var openDevices: [Int32: IOHIDDevice] = [:] // keyed by PID

    private init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        // Match only Logitech devices
        let matching = [kIOHIDVendorIDKey: LOGITECH_VID] as NSDictionary
        IOHIDManagerSetDeviceMatching(manager, matching)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        log("IOHIDManagerOpen: \(result)")

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }

    func getDevices() -> [(device: IOHIDDevice, name: String, pid: Int32)] {
        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            log("No devices from manager")
            return []
        }

        var results: [(IOHIDDevice, String, Int32)] = []
        var seenPIDs: Set<Int32> = []

        for device in deviceSet {
            let pid = (IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? NSNumber)?.int32Value ?? 0
            let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown"

            if KNOWN_PIDS.contains(pid) && !seenPIDs.contains(pid) {
                log("Manager found: \(name) (PID=0x\(String(pid, radix: 16, uppercase: true)))")
                results.append((device, name, pid))
                seenPIDs.insert(pid)
            }
        }

        return results
    }
}

private func sendReport(_ device: IOHIDDevice, featureIndex: UInt8, functionID: UInt8, _ params: UInt8...) -> IOReturn {
    var msg = [UInt8](repeating: 0, count: HIDPP_LONG_LEN)
    msg[0] = HIDPP_LONG_REPORT_ID
    msg[1] = BT_DEVICE_INDEX
    msg[2] = featureIndex
    msg[3] = (functionID << 4) | SW_ID
    for (i, p) in params.enumerated() {
        msg[4 + i] = p
    }
    return IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput,
                                 CFIndex(HIDPP_LONG_REPORT_ID), msg, msg.count)
}

private func readReport(_ device: IOHIDDevice) -> [UInt8]? {
    var buf = [UInt8](repeating: 0, count: HIDPP_LONG_LEN)
    var length = CFIndex(HIDPP_LONG_LEN)
    let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeInput,
                                       CFIndex(HIDPP_LONG_REPORT_ID), &buf, &length)
    guard result == kIOReturnSuccess else {
        log("readReport failed: \(result)")
        return nil
    }
    return Array(buf.prefix(length))
}

func switchDevice(_ device: IOHIDDevice, name: String, toHost host: Int) -> Bool {
    // Try opening the device explicitly first
    let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
    log("Open \(name): \(openResult)")

    // Query IRoot for ChangeHost feature index
    var kr = sendReport(device, featureIndex: 0x00, functionID: 0x00,
                        UInt8(CHANGE_HOST_FEATURE >> 8), UInt8(CHANGE_HOST_FEATURE & 0xFF))
    if kr != kIOReturnSuccess {
        log("IRoot query failed on \(name): \(kr)")
        return false
    }

    usleep(200_000)

    guard let resp = readReport(device), resp.count >= 5, resp[4] != 0 else {
        log("ChangeHost feature not found on \(name)")
        return false
    }

    let changeHostIdx = resp[4]
    log("ChangeHost index=0x\(String(changeHostIdx, radix: 16)) on \(name)")

    // setCurrentHost (function 1), 0-indexed
    kr = sendReport(device, featureIndex: changeHostIdx, functionID: 0x01, UInt8(host - 1))
    if kr != kIOReturnSuccess {
        log("Switch command failed on \(name): \(kr)")
        return false
    }

    log("Switched \(name) to host \(host)")
    return true
}

func switchAllDevices(to host: Int) {
    log("Switching all devices to host \(host)")
    let devices = HIDDeviceManager.shared.getDevices()
    if devices.isEmpty {
        log("No devices to switch")
        return
    }
    for (device, name, _) in devices {
        let ok = switchDevice(device, name: name, toHost: host)
        log("\(name) → host \(host): \(ok ? "OK" : "FAILED")")
    }
}

// MARK: - Menu Bar Controller

class MenuBarController: NSObject, NSMenuDelegate {
    let statusItem: NSStatusItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "Host Switcher")
                ?? NSImage(systemSymbolName: "arrow.triangle.swap", accessibilityDescription: "Host Switcher")
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        for i in 1...3 {
            let item = NSMenuItem(title: "Switch to Host \(i)", action: #selector(menuAction(_:)), keyEquivalent: "\(i)")
            item.keyEquivalentModifierMask = [.command, .option]
            item.tag = i
            item.target = self
            item.isEnabled = true
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = true
        menu.addItem(quitItem)

        statusItem.menu = menu
        log("Menu bar set up with \(menu.items.count) items")
    }

    func menuWillOpen(_ menu: NSMenu) {
        log("Menu opened — \(menu.items.count) items")
        for item in menu.items {
            log("  '\(item.title)' enabled=\(item.isEnabled) target=\(String(describing: item.target))")
        }
    }

    @objc func menuAction(_ sender: NSMenuItem) {
        let host = sender.tag
        log("Menu clicked: host \(host)")
        DispatchQueue.global(qos: .userInitiated).async {
            switchAllDevices(to: host)
        }
    }

    @objc func quit() {
        log("Quit clicked")
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBar: MenuBarController!
    var hotKeyRefs: [EventHotKeyRef?] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("App launched")
        _ = HIDDeviceManager.shared  // initialize manager early
        menuBar = MenuBarController()
        registerHotKeys()
        log("Ready")
    }

    private func registerHotKeys() {
        var handlerRef: EventHandlerRef?
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                            EventParamType(typeEventHotKeyID), nil,
                            MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let host = Int(hotKeyID.id)
            log("Hotkey pressed: host \(host)")
            DispatchQueue.global(qos: .userInitiated).async {
                switchAllDevices(to: host)
            }
            return noErr
        }, 1, &eventSpec, nil, &handlerRef)

        let sig = OSType(0x484F5354) // 'HOST'
        for i: UInt32 in 1...3 {
            let hkID = EventHotKeyID(signature: sig, id: i)
            var ref: EventHotKeyRef?
            RegisterEventHotKey(17 + i, UInt32(optionKey | cmdKey),
                              hkID, GetApplicationEventTarget(), 0, &ref)
            hotKeyRefs.append(ref)
        }
        log("Hotkeys registered")
    }
}

// MARK: - Main

log("HostSwitcher starting")
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
