# Mapping Config Reference

The bridge config lives at `config/mappings.json`.

## Top-level fields
- `appProfiles` (`object<string,string>`): map macOS bundle ID -> profile name.
- `profiles` (`object<string, ProfileConfig>`): named profile definitions.
- `safety` (`SafetyConfig`): runtime safety defaults.

Behavior note:
- The bridge does not use a global fallback profile.
- If the frontmost app bundle ID is not present in `appProfiles`, button events are ignored.

## ProfileConfig
- `enabled` (`bool`, optional, default `true`): disable an entire profile.
- `mappings` (`object<string, MappingConfig>`): button name -> mapping.

## MappingConfig
- `debounceMs` (`int`, optional): minimum interval between triggers.
- `edgeTrigger` (`bool`, optional, default `true`): when true, only fire on initial press.
- `action` (`ActionConfig`): action to execute.

## ActionConfig
- `type` (`"keystroke" | "holdKeystroke" | "shell" | "applescript" | "text"`)
- Keystroke fields:
  - `keyCode` (`int`, required)
  - `modifiers` (`string[]`, optional)
  - `postKeyCode` (`int`, optional): send this keystroke once after the primary keystroke.
  - `postModifiers` (`string[]`, optional): modifiers for `postKeyCode`.
  - `postDelayMs` (`int`, optional): delay before the post keystroke.
- Hold keystroke fields:
  - `keyCode` (`int`, required)
  - `modifiers` (`string[]`, optional)
  - `onReleaseKeyCode` (`int`, optional): send this keystroke once when the hold button is released.
  - `onReleaseModifiers` (`string[]`, optional): modifiers for `onReleaseKeyCode`.
  - `onReleaseDelayMs` (`int`, optional): delay before the release keystroke.
  - Behavior: key down on button press, key up on button release.
- Shell fields:
  - `command` (`string`, required)
- AppleScript fields:
  - `script` (`string`, required)
- Text fields:
  - `text` (`string`, required)
  - `preKeyCode` (`int`, optional): keystroke to send before typing text.
  - `preModifiers` (`string[]`, optional): modifiers for `preKeyCode`.
  - `preDelayMs` (`int`, optional): delay after pre-keystroke and before typing text.
  - `pressEnter` (`bool`, optional): if true, press Enter after typing text.
  - `delayMs` (`int`, optional): delay between typing text and Enter.
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

Availability note:
- A button name can be valid in config but never emit events at runtime if macOS does not expose that physical control via `GameController` for the current device/connection mode.
- On Stadia controllers specifically, `home` (Assistant) may be unavailable even when `menu`/`options`/`share` are available.
