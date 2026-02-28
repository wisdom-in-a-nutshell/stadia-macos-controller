import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import GameController

struct CLIOptions {
    let configPath: String
    let dryRunOverride: Bool?
    let promptAccessibility: Bool

    static func parse(arguments: [String]) throws -> CLIOptions {
        var configPath = "config/mappings.json"
        var dryRunOverride: Bool?
        var promptAccessibility = false

        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--config":
                let valueIndex = index + 1
                guard valueIndex < arguments.count else {
                    throw BridgeError.invalidArguments("Missing value for --config")
                }
                configPath = arguments[valueIndex]
                index = valueIndex + 1
            case "--dry-run":
                dryRunOverride = true
                index += 1
            case "--no-dry-run":
                dryRunOverride = false
                index += 1
            case "--help", "-h":
                Self.printHelp()
                Foundation.exit(0)
            case "--prompt-accessibility":
                promptAccessibility = true
                index += 1
            default:
                throw BridgeError.invalidArguments("Unknown argument: \(argument)")
            }
        }

        return CLIOptions(
            configPath: configPath,
            dryRunOverride: dryRunOverride,
            promptAccessibility: promptAccessibility
        )
    }

    static func printHelp() {
        let help = """
        Stadia macOS Controller Bridge

        Usage:
          swift run stadia-controller-bridge [options]

        Options:
          --config <path>   Path to mappings config JSON (default: config/mappings.json)
          --dry-run         Force dry-run mode (no key/command execution)
          --no-dry-run      Force live mode
          --prompt-accessibility  Ask macOS to show Accessibility permission prompt
          --help, -h        Show this help text
        """
        print(help)
    }
}

struct BridgeConfig: Decodable {
    let appProfiles: [String: String]
    let profiles: [String: ProfileConfig]
    let safety: SafetyConfig
}

struct ProfileConfig: Decodable {
    let enabled: Bool?
    let analog: AnalogConfig?
    let mappings: [String: MappingConfig]
}

struct AnalogConfig: Decodable {
    let leftStickVerticalScroll: LeftStickVerticalScrollConfig?
}

struct LeftStickVerticalScrollConfig: Decodable {
    let enabled: Bool?
    let deadzone: Double?
    let intervalMs: Int?
    let minLinesPerTick: Int?
    let maxLinesPerTick: Int?
    let responseExponent: Double?
    let invert: Bool?
}

struct MappingConfig: Decodable {
    let action: ActionConfig
    let debounceMs: Int?
    let edgeTrigger: Bool?
}

struct SafetyConfig: Decodable {
    let dryRun: Bool
    let emergencyToggleButton: String?
}

struct ActionConfig: Decodable {
    let type: ActionType
    let keyCode: Int?
    let modifiers: [String]?
    let command: String?
    let script: String?
    let text: String?
    let pressEnter: Bool?
    let delayMs: Int?
    let preKeyCode: Int?
    let preModifiers: [String]?
    let preDelayMs: Int?
    let description: String?
}

enum ActionType: String, Decodable {
    case keystroke
    case holdKeystroke
    case shell
    case applescript
    case text
}

struct ControllerEvent {
    let controllerID: String
    let button: String
    let pressed: Bool
    let timestamp: Date
    let isRepeat: Bool
}

enum BridgeError: Error, LocalizedError {
    case invalidArguments(String)
    case configLoadFailed(String)
    case configValidationFailed(String)
    case actionExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let message):
            return message
        case .configLoadFailed(let message):
            return message
        case .configValidationFailed(let message):
            return message
        case .actionExecutionFailed(let message):
            return message
        }
    }
}

struct ConfigLoader {
    static func load(path: String) throws -> BridgeConfig {
        let absolutePath = absolutePath(for: path)
        let data: Data

        do {
            data = try Data(contentsOf: URL(fileURLWithPath: absolutePath))
        } catch {
            throw BridgeError.configLoadFailed("Failed to read config at \(absolutePath): \(error.localizedDescription)")
        }

        let decoder = JSONDecoder()
        let config: BridgeConfig
        do {
            config = try decoder.decode(BridgeConfig.self, from: data)
        } catch {
            throw BridgeError.configLoadFailed("Failed to decode JSON config: \(error.localizedDescription)")
        }

        try validate(config: config)
        return config
    }

    static func absolutePath(for path: String) -> String {
        if path.hasPrefix("/") {
            return path
        }
        return URL(fileURLWithPath: path, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).path
    }

    private static func validate(config: BridgeConfig) throws {
        for (bundleID, profileName) in config.appProfiles {
            guard config.profiles[profileName] != nil else {
                throw BridgeError.configValidationFailed(
                    "appProfiles entry '\(bundleID)' references unknown profile '\(profileName)'"
                )
            }
        }

        for (profileName, profile) in config.profiles {
            for (button, mapping) in profile.mappings {
                switch mapping.action.type {
                case .keystroke:
                    guard mapping.action.keyCode != nil else {
                        throw BridgeError.configValidationFailed("Profile '\(profileName)' button '\(button)' keystroke action requires keyCode")
                    }
                case .holdKeystroke:
                    guard mapping.action.keyCode != nil else {
                        throw BridgeError.configValidationFailed("Profile '\(profileName)' button '\(button)' holdKeystroke action requires keyCode")
                    }
                case .shell:
                    guard let command = mapping.action.command, !command.isEmpty else {
                        throw BridgeError.configValidationFailed("Profile '\(profileName)' button '\(button)' shell action requires command")
                    }
                case .applescript:
                    guard let script = mapping.action.script, !script.isEmpty else {
                        throw BridgeError.configValidationFailed("Profile '\(profileName)' button '\(button)' applescript action requires script")
                    }
        case .text:
            guard let text = mapping.action.text, !text.isEmpty else {
                throw BridgeError.configValidationFailed("Profile '\(profileName)' button '\(button)' text action requires text")
            }
        }
            }

            if let analog = profile.analog?.leftStickVerticalScroll {
                if let deadzone = analog.deadzone, deadzone < 0 || deadzone >= 1 {
                    throw BridgeError.configValidationFailed("Profile '\(profileName)' leftStickVerticalScroll deadzone must be >= 0 and < 1")
                }
                if let intervalMs = analog.intervalMs, intervalMs < 1 {
                    throw BridgeError.configValidationFailed("Profile '\(profileName)' leftStickVerticalScroll intervalMs must be >= 1")
                }
                if let minLines = analog.minLinesPerTick, minLines < 1 {
                    throw BridgeError.configValidationFailed("Profile '\(profileName)' leftStickVerticalScroll minLinesPerTick must be >= 1")
                }
                if let maxLines = analog.maxLinesPerTick, maxLines < 1 {
                    throw BridgeError.configValidationFailed("Profile '\(profileName)' leftStickVerticalScroll maxLinesPerTick must be >= 1")
                }
                if let minLines = analog.minLinesPerTick,
                   let maxLines = analog.maxLinesPerTick,
                   maxLines < minLines {
                    throw BridgeError.configValidationFailed("Profile '\(profileName)' leftStickVerticalScroll maxLinesPerTick must be >= minLinesPerTick")
                }
                if let responseExponent = analog.responseExponent, responseExponent <= 0 {
                    throw BridgeError.configValidationFailed("Profile '\(profileName)' leftStickVerticalScroll responseExponent must be > 0")
                }
            }
        }
    }
}

final class ProfileResolver {
    private let appProfiles: [String: String]

    init(appProfiles: [String: String]) {
        self.appProfiles = appProfiles
    }

    func resolveActiveProfile() -> String? {
        guard let bundleID = currentFrontmostBundleID() else {
            return nil
        }

        return appProfiles[bundleID]
    }

    func currentFrontmostBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}

final class ActionExecutor {
    private let dryRun: Bool

    init(dryRun: Bool) {
        self.dryRun = dryRun
    }

    func execute(action: ActionConfig, profile: String, button: String) throws {
        let description = action.description ?? "(no description)"

        if dryRun {
            print("[DRY-RUN] profile=\(profile) button=\(button) action=\(description)")
            return
        }

        switch action.type {
        case .keystroke:
            guard let keyCodeValue = action.keyCode else {
                throw BridgeError.actionExecutionFailed("Keystroke action missing keyCode")
            }

            if !AXIsProcessTrusted() {
                throw BridgeError.actionExecutionFailed("Accessibility permission is required for keystroke injection")
            }

            let keyCode = CGKeyCode(keyCodeValue)
            let flags = modifierFlags(from: action.modifiers ?? [])
            try postKeystroke(keyCode: keyCode, modifiers: flags)
            print("[ACTION] keystroke keyCode=\(keyCodeValue) profile=\(profile) button=\(button)")

        case .holdKeystroke:
            throw BridgeError.actionExecutionFailed("holdKeystroke must be handled as press/release lifecycle")

        case .shell:
            guard let command = action.command else {
                throw BridgeError.actionExecutionFailed("Shell action missing command")
            }

            try runProcess(executable: "/bin/zsh", arguments: ["-lc", command])
            print("[ACTION] shell profile=\(profile) button=\(button) command=\(command)")

        case .applescript:
            guard let script = action.script else {
                throw BridgeError.actionExecutionFailed("AppleScript action missing script")
            }

            try runProcess(executable: "/usr/bin/osascript", arguments: ["-e", script])
            print("[ACTION] applescript profile=\(profile) button=\(button)")

        case .text:
            guard let text = action.text else {
                throw BridgeError.actionExecutionFailed("Text action missing text")
            }

            if !AXIsProcessTrusted() {
                throw BridgeError.actionExecutionFailed("Accessibility permission is required for typed text injection")
            }

            if let preKeyCodeValue = action.preKeyCode {
                let preFlags = modifierFlags(from: action.preModifiers ?? [])
                try postKeystroke(keyCode: CGKeyCode(preKeyCodeValue), modifiers: preFlags)

                if let preDelayMs = action.preDelayMs, preDelayMs > 0 {
                    Thread.sleep(forTimeInterval: Double(preDelayMs) / 1000.0)
                }
            }

            try postText(text)

            if let delayMs = action.delayMs, delayMs > 0 {
                Thread.sleep(forTimeInterval: Double(delayMs) / 1000.0)
            }

            if action.pressEnter == true {
                try postKeystroke(keyCode: 36, modifiers: [])
            }

            print("[ACTION] text profile=\(profile) button=\(button) text=\(text)")
        }
    }

    func beginHold(action: ActionConfig, profile: String, button: String) throws {
        guard action.type == .holdKeystroke else {
            throw BridgeError.actionExecutionFailed("beginHold requires holdKeystroke action")
        }
        guard let keyCodeValue = action.keyCode else {
            throw BridgeError.actionExecutionFailed("holdKeystroke action missing keyCode")
        }

        if dryRun {
            print("[DRY-RUN] hold-begin profile=\(profile) button=\(button) keyCode=\(keyCodeValue)")
            return
        }

        if !AXIsProcessTrusted() {
            throw BridgeError.actionExecutionFailed("Accessibility permission is required for hold keystroke injection")
        }

        let keyCode = CGKeyCode(keyCodeValue)
        let flags = modifierFlags(from: action.modifiers ?? [])
        try postKeyEvent(keyCode: keyCode, keyDown: true, modifiers: flags)
        print("[ACTION] hold-begin keyCode=\(keyCodeValue) profile=\(profile) button=\(button)")
    }

    func endHold(action: ActionConfig, profile: String, button: String) throws {
        guard action.type == .holdKeystroke else {
            throw BridgeError.actionExecutionFailed("endHold requires holdKeystroke action")
        }
        guard let keyCodeValue = action.keyCode else {
            throw BridgeError.actionExecutionFailed("holdKeystroke action missing keyCode")
        }

        if dryRun {
            print("[DRY-RUN] hold-end profile=\(profile) button=\(button) keyCode=\(keyCodeValue)")
            return
        }

        if !AXIsProcessTrusted() {
            throw BridgeError.actionExecutionFailed("Accessibility permission is required for hold keystroke injection")
        }

        let keyCode = CGKeyCode(keyCodeValue)
        let flags = modifierFlags(from: action.modifiers ?? [])
        try postKeyEvent(keyCode: keyCode, keyDown: false, modifiers: flags)
        print("[ACTION] hold-end keyCode=\(keyCodeValue) profile=\(profile) button=\(button)")
    }

    func scrollVertical(lines: Int, profile: String, source: String) throws {
        guard lines != 0 else {
            return
        }

        if dryRun {
            print("[DRY-RUN] scroll profile=\(profile) source=\(source) lines=\(lines)")
            return
        }

        if !AXIsProcessTrusted() {
            throw BridgeError.actionExecutionFailed("Accessibility permission is required for scroll injection")
        }

        guard let eventSource = CGEventSource(stateID: .hidSystemState),
              let scrollEvent = CGEvent(
                scrollWheelEvent2Source: eventSource,
                units: .line,
                wheelCount: 1,
                wheel1: Int32(lines),
                wheel2: 0,
                wheel3: 0
              ) else {
            throw BridgeError.actionExecutionFailed("Failed to create scroll event")
        }

        scrollEvent.post(tap: .cghidEventTap)
        print("[ACTION] scroll profile=\(profile) source=\(source) lines=\(lines)")
    }

    private func modifierFlags(from modifiers: [String]) -> CGEventFlags {
        modifiers.reduce(CGEventFlags()) { partial, modifier in
            switch modifier.lowercased() {
            case "command", "cmd":
                return partial.union(.maskCommand)
            case "shift":
                return partial.union(.maskShift)
            case "option", "alt":
                return partial.union(.maskAlternate)
            case "control", "ctrl":
                return partial.union(.maskControl)
            default:
                return partial
            }
        }
    }

    private func postKeystroke(keyCode: CGKeyCode, modifiers: CGEventFlags) throws {
        try postKeyEvent(keyCode: keyCode, keyDown: true, modifiers: modifiers)
        try postKeyEvent(keyCode: keyCode, keyDown: false, modifiers: modifiers)
    }


    private func postKeyEvent(keyCode: CGKeyCode, keyDown: Bool, modifiers: CGEventFlags) throws {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown) else {
            throw BridgeError.actionExecutionFailed("Failed to create keyboard event")
        }

        event.flags = modifiers
        event.post(tap: .cghidEventTap)
    }

    private func postText(_ text: String) throws {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw BridgeError.actionExecutionFailed("Failed to create keyboard source for text action")
        }

        for scalar in text.utf16 {
            var character = scalar
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                throw BridgeError.actionExecutionFailed("Failed to create keyboard event for text action")
            }

            keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &character)
            keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &character)
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }

    private func runProcess(executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw BridgeError.actionExecutionFailed("Process failed to start: \(error.localizedDescription)")
        }

        guard process.terminationStatus == 0 else {
            throw BridgeError.actionExecutionFailed("Process exited with status \(process.terminationStatus)")
        }
    }
}

final class ControllerBridge: NSObject {
    private var config: BridgeConfig
    private var profileResolver: ProfileResolver
    private var actionExecutor: ActionExecutor

    private let configPath: String
    private let dryRunOverride: Bool?

    private var buttonStates: [String: Bool] = [:]
    private var lastTriggeredAt: [String: Date] = [:]
    private var lastAnalogScrollAt: [String: Date] = [:]
    private var polledButtonStates: [String: Bool] = [:]
    private var activeGamepads: [String: GCExtendedGamepad] = [:]
    private var activeControllers: [String: GCController] = [:]
    private var pollingTimer: Timer?
    private var configWatchTimer: Timer?
    private var configLastModified: Date?
    private var activeHolds: [String: (profileName: String, action: ActionConfig)] = [:]
    private var bridgeEnabled = true

    init(config: BridgeConfig, configPath: String, dryRunOverride: Bool?, promptAccessibility: Bool) {
        self.config = config
        self.profileResolver = ProfileResolver(appProfiles: config.appProfiles)
        self.configPath = configPath
        self.dryRunOverride = dryRunOverride

        let dryRun = Self.effectiveDryRun(for: config, dryRunOverride: dryRunOverride)
        self.actionExecutor = ActionExecutor(dryRun: dryRun)
        super.init()

        print("Bridge mode: \(dryRun ? "dry-run" : "live")")
        if !dryRun && !AXIsProcessTrusted() {
            print("WARNING: Accessibility permission is not granted. Keystroke actions will fail until enabled.")
            if promptAccessibility {
                promptForAccessibilityPermission()
            }
        }
    }

    deinit {
        pollingTimer?.invalidate()
        configWatchTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
        GCController.shouldMonitorBackgroundEvents = true
        print("[INFO] GCController.shouldMonitorBackgroundEvents=true")
        registerControllerNotifications()
        startConfigWatcher()

        let existingControllers = GCController.controllers()
        if existingControllers.isEmpty {
            print("No controller currently connected. Waiting for Stadia controller...")
        } else {
            existingControllers.forEach(registerHandlers)
        }

        GCController.startWirelessControllerDiscovery {
            print("Wireless discovery finished")
        }

        print("Bridge started. Press Ctrl+C to stop.")
        RunLoop.main.run()
    }

    private static func effectiveDryRun(for config: BridgeConfig, dryRunOverride: Bool?) -> Bool {
        dryRunOverride ?? config.safety.dryRun
    }

    private func registerControllerNotifications() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleControllerDidConnect(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleControllerDidDisconnect(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )
    }

    @objc
    private func handleControllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else {
            return
        }
        registerHandlers(for: controller)
    }

    @objc
    private func handleControllerDidDisconnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else {
            return
        }
        let controllerID = Self.controllerID(for: controller)
        activeGamepads.removeValue(forKey: controllerID)
        activeControllers.removeValue(forKey: controllerID)
        buttonStates = buttonStates.filter { !$0.key.hasPrefix("\(controllerID)::") }
        lastAnalogScrollAt = lastAnalogScrollAt.filter { !$0.key.hasPrefix("\(controllerID)::") }
        polledButtonStates = polledButtonStates.filter { !$0.key.hasPrefix("\(controllerID)::") }
        activeHolds = activeHolds.filter { !$0.key.hasPrefix("\(controllerID)::") }
        print("Controller disconnected: \(controllerID)")
    }

    private func registerHandlers(for controller: GCController) {
        let controllerID = Self.controllerID(for: controller)
        let vendor = controller.vendorName ?? "Unknown Vendor"
        print("Controller connected: \(vendor) id=\(controllerID)")

        guard let gamepad = controller.extendedGamepad else {
            print("Controller \(controllerID) does not expose extended gamepad profile; ignoring")
            return
        }

        activeGamepads[controllerID] = gamepad
        activeControllers[controllerID] = controller
        startPollingIfNeeded()
        print("[INFO] Registered polling for controller id=\(controllerID)")
    }

    private func startPollingIfNeeded() {
        if pollingTimer != nil {
            return
        }

        pollingTimer = Timer.scheduledTimer(
            timeInterval: 0.02,
            target: self,
            selector: #selector(pollControllers),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(pollingTimer!, forMode: .common)
    }

    private func startConfigWatcher() {
        configLastModified = configModificationDate(path: configPath)
        configWatchTimer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(checkConfigForChanges),
            userInfo: nil,
            repeats: true
        )
        if let configWatchTimer {
            RunLoop.main.add(configWatchTimer, forMode: .common)
        }
        print("[INFO] Config hot-reload watching \(configPath)")
    }

    @objc
    private func checkConfigForChanges() {
        guard let currentModified = configModificationDate(path: configPath) else {
            return
        }

        if let configLastModified, currentModified <= configLastModified {
            return
        }

        configLastModified = currentModified
        reloadConfigFromDisk()
    }

    private func reloadConfigFromDisk() {
        do {
            let newConfig = try ConfigLoader.load(path: configPath)
            let oldDryRun = Self.effectiveDryRun(for: config, dryRunOverride: dryRunOverride)
            let newDryRun = Self.effectiveDryRun(for: newConfig, dryRunOverride: dryRunOverride)

            config = newConfig
            profileResolver = ProfileResolver(appProfiles: newConfig.appProfiles)

            if oldDryRun != newDryRun {
                actionExecutor = ActionExecutor(dryRun: newDryRun)
                print("[CONFIG] Reloaded. Bridge mode changed to \(newDryRun ? "dry-run" : "live").")
            } else {
                print("[CONFIG] Reloaded mappings from disk.")
            }
        } catch {
            print("[CONFIG] Reload failed: \(error.localizedDescription)")
        }
    }

    private func configModificationDate(path: String) -> Date? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let modified = attributes[.modificationDate] as? Date else {
            return nil
        }
        return modified
    }

    @objc
    private func pollControllers() {
        for (controllerID, gamepad) in activeGamepads {
            pollButton(controllerID: controllerID, buttonName: "a", pressed: gamepad.buttonA.isPressed)
            pollButton(controllerID: controllerID, buttonName: "b", pressed: gamepad.buttonB.isPressed)
            pollButton(controllerID: controllerID, buttonName: "x", pressed: gamepad.buttonX.isPressed)
            pollButton(controllerID: controllerID, buttonName: "y", pressed: gamepad.buttonY.isPressed)
            pollButton(controllerID: controllerID, buttonName: "leftShoulder", pressed: gamepad.leftShoulder.isPressed)
            pollButton(controllerID: controllerID, buttonName: "rightShoulder", pressed: gamepad.rightShoulder.isPressed)
            pollButton(controllerID: controllerID, buttonName: "leftTrigger", pressed: gamepad.leftTrigger.isPressed)
            pollButton(controllerID: controllerID, buttonName: "rightTrigger", pressed: gamepad.rightTrigger.isPressed)
            pollButton(controllerID: controllerID, buttonName: "menu", pressed: gamepad.buttonMenu.isPressed)
            if let buttonOptions = gamepad.buttonOptions {
                pollButton(controllerID: controllerID, buttonName: "options", pressed: buttonOptions.isPressed)
            }
            if let controller = activeControllers[controllerID] {
                pollPhysicalButton(
                    controllerID: controllerID,
                    controller: controller,
                    elementName: GCInputButtonHome,
                    mappedButtonName: "home"
                )
                pollPhysicalButton(
                    controllerID: controllerID,
                    controller: controller,
                    elementName: GCInputButtonShare,
                    mappedButtonName: "share"
                )
            }
            if let leftThumbstickButton = gamepad.leftThumbstickButton {
                pollButton(controllerID: controllerID, buttonName: "leftThumbstickButton", pressed: leftThumbstickButton.isPressed)
            }
            if let rightThumbstickButton = gamepad.rightThumbstickButton {
                pollButton(controllerID: controllerID, buttonName: "rightThumbstickButton", pressed: rightThumbstickButton.isPressed)
            }
            pollButton(controllerID: controllerID, buttonName: "dpadUp", pressed: gamepad.dpad.up.isPressed)
            pollButton(controllerID: controllerID, buttonName: "dpadDown", pressed: gamepad.dpad.down.isPressed)
            pollButton(controllerID: controllerID, buttonName: "dpadLeft", pressed: gamepad.dpad.left.isPressed)
            pollButton(controllerID: controllerID, buttonName: "dpadRight", pressed: gamepad.dpad.right.isPressed)
            pollLeftStickVerticalScroll(controllerID: controllerID, gamepad: gamepad)
        }
    }

    private func pollPhysicalButton(
        controllerID: String,
        controller: GCController,
        elementName: String,
        mappedButtonName: String
    ) {
        guard let element = controller.physicalInputProfile.elements[elementName],
              let button = element as? GCControllerButtonInput else {
            return
        }

        pollButton(controllerID: controllerID, buttonName: mappedButtonName, pressed: button.isPressed)
    }

    private func pollButton(controllerID: String, buttonName: String, pressed: Bool) {
        let stateKey = "\(controllerID)::\(buttonName)"
        let previous = polledButtonStates[stateKey] ?? false
        guard previous != pressed else {
            return
        }

        polledButtonStates[stateKey] = pressed
        handleButtonEvent(controllerID: controllerID, buttonName: buttonName, pressed: pressed)
    }

    private func pollLeftStickVerticalScroll(controllerID: String, gamepad: GCExtendedGamepad) {
        guard bridgeEnabled else {
            return
        }

        guard let activeProfileName = profileResolver.resolveActiveProfile(),
              let profile = config.profiles[activeProfileName],
              profile.enabled ?? true,
              let scroll = profile.analog?.leftStickVerticalScroll,
              scroll.enabled ?? true else {
            return
        }

        let rawY = Double(gamepad.leftThumbstick.yAxis.value)
        let deadzone = min(max(scroll.deadzone ?? 0.22, 0.0), 0.99)
        let magnitude = abs(rawY)
        guard magnitude > deadzone else {
            return
        }

        let intervalMs = max(1, scroll.intervalMs ?? 45)
        let throttleKey = "\(controllerID)::\(activeProfileName)::leftStickVerticalScroll"
        let now = Date()
        if let last = lastAnalogScrollAt[throttleKey] {
            let deltaMs = Int(now.timeIntervalSince(last) * 1000)
            if deltaMs < intervalMs {
                return
            }
        }

        let normalized = min(1.0, max(0.0, (magnitude - deadzone) / max(0.001, 1.0 - deadzone)))
        let responseExponent = max(0.1, scroll.responseExponent ?? 1.8)
        let curved = pow(normalized, responseExponent)
        let minLines = max(1, scroll.minLinesPerTick ?? 1)
        let maxLines = max(minLines, scroll.maxLinesPerTick ?? 8)
        let scaledLines = Double(minLines) + curved * Double(maxLines - minLines)
        let linesPerTick = max(1, Int(round(scaledLines)))

        let direction = rawY >= 0 ? 1 : -1
        let signedLines = (scroll.invert == true ? -direction : direction) * linesPerTick
        guard signedLines != 0 else {
            return
        }

        do {
            try actionExecutor.scrollVertical(
                lines: signedLines,
                profile: activeProfileName,
                source: "leftStickY"
            )
            lastAnalogScrollAt[throttleKey] = now
        } catch {
            print("[ERROR] analog scroll failed: \(error.localizedDescription)")
        }
    }

    private func promptForAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        print("[INFO] Requested macOS Accessibility permission prompt for this terminal app.")
    }

    private func handleButtonEvent(controllerID: String, buttonName: String, pressed: Bool) {
        let now = Date()
        let stateKey = "\(controllerID)::\(buttonName)"
        let previousState = buttonStates[stateKey] ?? false
        let isRepeat = pressed && previousState
        buttonStates[stateKey] = pressed

        let event = ControllerEvent(
            controllerID: controllerID,
            button: buttonName,
            pressed: pressed,
            timestamp: now,
            isRepeat: isRepeat
        )

        print("[EVENT] controller=\(event.controllerID) button=\(event.button) pressed=\(event.pressed) repeat=\(event.isRepeat)")

        guard event.pressed else {
            if let held = activeHolds.removeValue(forKey: stateKey) {
                do {
                    try actionExecutor.endHold(action: held.action, profile: held.profileName, button: event.button)
                } catch {
                    print("[ERROR] hold release failed: \(error.localizedDescription)")
                }
            }
            return
        }

        let bundleID = profileResolver.currentFrontmostBundleID() ?? "unknown"

        if let emergencyButton = config.safety.emergencyToggleButton,
           event.button == emergencyButton {
            bridgeEnabled.toggle()
            print("[SAFETY] bridgeEnabled=\(bridgeEnabled)")
            return
        }

        guard bridgeEnabled else {
            print("[SKIP] Bridge disabled via emergency toggle")
            return
        }

        guard let activeProfileName = profileResolver.resolveActiveProfile() else {
            print("[SKIP] no active app profile bundle=\(bundleID) button=\(event.button)")
            return
        }

        guard let resolved = resolveMapping(forButton: event.button, activeProfileName: activeProfileName) else {
            print("[SKIP] no mapping profile=\(activeProfileName) bundle=\(bundleID) button=\(event.button)")
            return
        }

        print("[MAP] profile=\(resolved.profileName) bundle=\(bundleID) button=\(event.button)")

        if event.isRepeat && resolved.mapping.edgeTrigger != false {
            return
        }

        if resolved.mapping.action.type == .holdKeystroke {
            do {
                try actionExecutor.beginHold(action: resolved.mapping.action, profile: resolved.profileName, button: event.button)
                activeHolds[stateKey] = (resolved.profileName, resolved.mapping.action)
            } catch {
                print("[ERROR] hold begin failed: \(error.localizedDescription)")
            }
            return
        }

        let debounceMs = resolved.mapping.debounceMs ?? 200
        let debounceKey = "\(resolved.profileName)::\(event.button)"

        if let last = lastTriggeredAt[debounceKey] {
            let deltaMs = Int(now.timeIntervalSince(last) * 1000)
            if deltaMs < debounceMs {
                print("[SKIP] debounce profile=\(resolved.profileName) button=\(event.button) deltaMs=\(deltaMs)")
                return
            }
        }

        do {
            try actionExecutor.execute(action: resolved.mapping.action, profile: resolved.profileName, button: event.button)
            lastTriggeredAt[debounceKey] = now
        } catch {
            print("[ERROR] action failed: \(error.localizedDescription)")
        }
    }

    private func resolveMapping(forButton button: String, activeProfileName: String) -> (profileName: String, mapping: MappingConfig)? {
        if let activeProfile = config.profiles[activeProfileName], activeProfile.enabled ?? true,
           let mapping = activeProfile.mappings[button] {
            return (activeProfileName, mapping)
        }

        return nil
    }

    private static func controllerID(for controller: GCController) -> String {
        let objectID = ObjectIdentifier(controller).hashValue
        return String(objectID)
    }
}

func run() throws {
    let options = try CLIOptions.parse(arguments: CommandLine.arguments)
    let configPath = ConfigLoader.absolutePath(for: options.configPath)
    let config = try ConfigLoader.load(path: configPath)

    let bridge = ControllerBridge(
        config: config,
        configPath: configPath,
        dryRunOverride: options.dryRunOverride,
        promptAccessibility: options.promptAccessibility
    )
    bridge.start()
}

do {
    try run()
} catch {
    print("Fatal: \(error.localizedDescription)")
    Foundation.exit(1)
}
