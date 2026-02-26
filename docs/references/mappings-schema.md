# Mapping Config Reference

The bridge config lives at `config/mappings.json`.

## Top-level fields
- `appProfiles` (`object<string,string>`): map macOS bundle ID -> profile name.
- `profiles` (`object<string, ProfileConfig>`): named profile definitions.
- `safety` (`SafetyConfig`): runtime safety defaults.

## ProfileConfig
- `enabled` (`bool`, optional, default `true`): disable an entire profile.
- `mappings` (`object<string, MappingConfig>`): button name -> mapping.

## MappingConfig
- `debounceMs` (`int`, optional): minimum interval between triggers.
- `edgeTrigger` (`bool`, optional, default `true`): when true, only fire on initial press.
- `action` (`ActionConfig`): action to execute.

## ActionConfig
- `type` (`"keystroke" | "holdKeystroke" | "shell" | "applescript"`)
- Keystroke fields:
  - `keyCode` (`int`, required)
  - `modifiers` (`string[]`, optional)
- Hold keystroke fields:
  - `keyCode` (`int`, required)
  - `modifiers` (`string[]`, optional)
  - Behavior: key down on button press, key up on button release.
- Shell fields:
  - `command` (`string`, required)
- AppleScript fields:
  - `script` (`string`, required)
- Optional shared field:
  - `description` (`string`)

## SafetyConfig
- `dryRun` (`bool`): if true, print actions without executing.
- `emergencyToggleButton` (`string`, optional): pressing this button toggles bridge enablement.

## Known Button Names
- `a`, `b`, `x`, `y`
- `leftShoulder`, `rightShoulder`
- `leftTrigger`, `rightTrigger`
- `dpadUp`, `dpadDown`, `dpadLeft`, `dpadRight`
- `menu`, `options`
- `home`, `share` (Assistant/Capture on Stadia controller)
- `leftThumbstickButton`, `rightThumbstickButton`
