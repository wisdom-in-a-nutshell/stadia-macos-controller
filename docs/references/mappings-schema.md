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
- `analog` (`AnalogConfig`, optional): analog-axis behaviors for this profile.
- `mappings` (`object<string, MappingConfig>`): button name -> mapping.

## AnalogConfig
- `leftStickVerticalScroll` (`StickVerticalScrollConfig`, optional): map left stick `Y` axis to vertical scrolling.
- `rightStickVerticalScroll` (`StickVerticalScrollConfig`, optional): map right stick `Y` axis to vertical scrolling.
- `rightStickPointer` (`StickPointerConfig`, optional): map right stick `X/Y` axes to mouse pointer movement.

## StickVerticalScrollConfig
- `enabled` (`bool`, optional, default `true`)
- `deadzone` (`double`, optional, default `0.22`): ignore small stick drift (`>= 0`, `< 1`).
- `intervalMs` (`int`, optional, default `45`): minimum time between scroll ticks.
- `minLinesPerTick` (`int`, optional, default `1`): slowest scroll step when just outside deadzone.
- `maxLinesPerTick` (`int`, optional, default `8`): fastest scroll step at full tilt.
- `responseExponent` (`double`, optional, default `1.8`): acceleration curve shape (`> 1` is smoother/finer near center, `< 1` is more aggressive).
- `invert` (`bool`, optional, default `false`): invert axis direction.

## StickPointerConfig
- `enabled` (`bool`, optional, default `true`)
- `deadzone` (`double`, optional, default `0.16`): ignore small right-stick drift (`>= 0`, `< 1`).
- `intervalMs` (`int`, optional, default `16`): minimum time between pointer move ticks.
- `minPixelsPerTick` (`int`, optional, default `1`): slowest pointer step outside deadzone.
- `maxPixelsPerTick` (`int`, optional, default `24`): fastest pointer step at full tilt.
- `responseExponent` (`double`, optional, default `1.6`): acceleration curve (`> 1` gives finer center control).
- `invertX` (`bool`, optional, default `false`): invert horizontal direction.
- `invertY` (`bool`, optional, default `false`): invert vertical direction.

## MappingConfig
- `debounceMs` (`int`, optional): minimum interval between triggers.
- `edgeTrigger` (`bool`, optional, default `true`): when true, only fire on initial press.
- `action` (`ActionConfig`): action to execute.

## ActionConfig
- `type` (`"keystroke" | "holdKeystroke" | "shell" | "applescript" | "text"`)
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
