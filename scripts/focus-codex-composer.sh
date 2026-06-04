#!/usr/bin/env bash
set -euo pipefail

open -b com.openai.codex

coords="$(
  swift - 2>/dev/null <<'SWIFT'
import CoreGraphics
import Foundation

let deadline = Date().addingTimeInterval(1.2)

func codexWindowBounds() -> CGRect? {
    let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
    guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return nil
    }

    let candidates = windows.compactMap { window -> CGRect? in
        guard (window[kCGWindowOwnerName as String] as? String) == "Codex",
              (window[kCGWindowLayer as String] as? Int) == 0,
              (window[kCGWindowAlpha as String] as? Double ?? 0) > 0.5,
              let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
              let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
              bounds.width > 300,
              bounds.height > 300
        else {
            return nil
        }
        return bounds
    }

    return candidates.max { ($0.width * $0.height) < ($1.width * $1.height) }
}

while Date() < deadline {
    if let bounds = codexWindowBounds() {
        let x = Int(bounds.midX.rounded())
        let y = Int((bounds.maxY - 90).rounded())
        print("\(x) \(y)")
        exit(0)
    }
    Thread.sleep(forTimeInterval: 0.05)
}

exit(1)
SWIFT
)"

read -r x y <<< "$coords"
osascript -e "tell application \"System Events\" to click at {$x, $y}" >/dev/null
