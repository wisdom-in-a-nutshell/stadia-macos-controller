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
    let mappings: [String: MappingConfig]
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
    let description: String?
}

enum ActionType: String, Decodable {
    case keystroke
    case holdKeystroke
    case shell
    case applescript
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
        let absolutePath = resolvedPath(for: path)
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

    private static func resolvedPath(for path: String) -> String {
        if path.hasPrefix("/") {
            return path
        }
        return URL(fileURLWithPath: path, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).path
    }

    private static func validate(config: BridgeConfig) throws {
        guard config.profiles["default"] != nil else {
            throw BridgeError.configValidationFailed("Config must include a 'default' profile")
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

    func resolveActiveProfile() -> String {
        guard let bundleID = currentFrontmostBundleID() else {
            return "default"
        }

        return appProfiles[bundleID] ?? "default"
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
    private let config: BridgeConfig
    private let profileResolver: ProfileResolver
    private let actionExecutor: ActionExecutor

    private var buttonStates: [String: Bool] = [:]
    private var lastTriggeredAt: [String: Date] = [:]
    private var polledButtonStates: [String: Bool] = [:]
    private var activeGamepads: [String: GCExtendedGamepad] = [:]
    private var pollingTimer: Timer?
    private var activeHolds: [String: (profileName: String, action: ActionConfig)] = [:]
    private var bridgeEnabled = true

    init(config: BridgeConfig, dryRunOverride: Bool?, promptAccessibility: Bool) {
        self.config = config
        self.profileResolver = ProfileResolver(appProfiles: config.appProfiles)

        let dryRun = dryRunOverride ?? config.safety.dryRun
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
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
        GCController.shouldMonitorBackgroundEvents = true
        print("[INFO] GCController.shouldMonitorBackgroundEvents=true")
        registerControllerNotifications()

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
        buttonStates = buttonStates.filter { !$0.key.hasPrefix("\(controllerID)::") }
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
        }
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
        let activeProfileName = profileResolver.resolveActiveProfile()

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
        let defaultProfile = config.profiles["default"]

        if let activeProfile = config.profiles[activeProfileName], activeProfile.enabled ?? true,
           let mapping = activeProfile.mappings[button] {
            return (activeProfileName, mapping)
        }

        if let defaultProfile,
           defaultProfile.enabled ?? true,
           let mapping = defaultProfile.mappings[button] {
            return ("default", mapping)
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
    let config = try ConfigLoader.load(path: options.configPath)

    let bridge = ControllerBridge(
        config: config,
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
