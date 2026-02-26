import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import GameController

struct CLIOptions {
    let configPath: String
    let dryRunOverride: Bool?

    static func parse(arguments: [String]) throws -> CLIOptions {
        var configPath = "config/mappings.json"
        var dryRunOverride: Bool?

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
            default:
                throw BridgeError.invalidArguments("Unknown argument: \(argument)")
            }
        }

        return CLIOptions(configPath: configPath, dryRunOverride: dryRunOverride)
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
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return "default"
        }

        return appProfiles[bundleID] ?? "default"
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
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            throw BridgeError.actionExecutionFailed("Failed to create keyboard events")
        }

        keyDown.flags = modifiers
        keyUp.flags = modifiers

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
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
    private var bridgeEnabled = true

    init(config: BridgeConfig, dryRunOverride: Bool?) {
        self.config = config
        self.profileResolver = ProfileResolver(appProfiles: config.appProfiles)

        let dryRun = dryRunOverride ?? config.safety.dryRun
        self.actionExecutor = ActionExecutor(dryRun: dryRun)
        super.init()

        print("Bridge mode: \(dryRun ? "dry-run" : "live")")
        if !dryRun && !AXIsProcessTrusted() {
            print("WARNING: Accessibility permission is not granted. Keystroke actions will fail until enabled.")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
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

        bind(gamepad.buttonA, buttonName: "a", controllerID: controllerID)
        bind(gamepad.buttonB, buttonName: "b", controllerID: controllerID)
        bind(gamepad.buttonX, buttonName: "x", controllerID: controllerID)
        bind(gamepad.buttonY, buttonName: "y", controllerID: controllerID)
        bind(gamepad.leftShoulder, buttonName: "leftShoulder", controllerID: controllerID)
        bind(gamepad.rightShoulder, buttonName: "rightShoulder", controllerID: controllerID)
        bind(gamepad.leftTrigger, buttonName: "leftTrigger", controllerID: controllerID)
        bind(gamepad.rightTrigger, buttonName: "rightTrigger", controllerID: controllerID)
        bind(gamepad.dpad.up, buttonName: "dpadUp", controllerID: controllerID)
        bind(gamepad.dpad.down, buttonName: "dpadDown", controllerID: controllerID)
        bind(gamepad.dpad.left, buttonName: "dpadLeft", controllerID: controllerID)
        bind(gamepad.dpad.right, buttonName: "dpadRight", controllerID: controllerID)

        bind(gamepad.buttonMenu, buttonName: "menu", controllerID: controllerID)

        if let buttonOptions = gamepad.buttonOptions {
            bind(buttonOptions, buttonName: "options", controllerID: controllerID)
        }

        if let leftThumbstickButton = gamepad.leftThumbstickButton {
            bind(leftThumbstickButton, buttonName: "leftThumbstickButton", controllerID: controllerID)
        }

        if let rightThumbstickButton = gamepad.rightThumbstickButton {
            bind(rightThumbstickButton, buttonName: "rightThumbstickButton", controllerID: controllerID)
        }
    }

    private func bind(_ input: GCControllerButtonInput, buttonName: String, controllerID: String) {
        input.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonEvent(controllerID: controllerID, buttonName: buttonName, pressed: pressed)
        }
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
            return
        }

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

        guard let resolved = resolveMapping(forButton: event.button) else {
            return
        }

        if event.isRepeat && resolved.mapping.edgeTrigger != false {
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

    private func resolveMapping(forButton button: String) -> (profileName: String, mapping: MappingConfig)? {
        let activeProfileName = profileResolver.resolveActiveProfile()
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

    let bridge = ControllerBridge(config: config, dryRunOverride: options.dryRunOverride)
    bridge.start()
}

do {
    try run()
} catch {
    print("Fatal: \(error.localizedDescription)")
    Foundation.exit(1)
}
