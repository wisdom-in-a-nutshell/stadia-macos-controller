# Stadia macOS Controller Bridge

## What This Does (Simple)
- Reads Stadia controller input on macOS.
- Runs a local bridge service.
- Converts mapped button presses into keystroke actions.
- Sends those actions to Ghostty.

## Simple Flow (Mermaid)
```mermaid
flowchart TD
  C[Stadia Controller] --> B[Stadia Controller Bridge]
  B --> K[Keystroke Actions]
  K --> G[Ghostty]
```

## Simple Flow (ASCII)
```text
┌──────────────────────────┐
│                          │
│    Stadia Controller     │
│                          │
└─────────────┬────────────┘
              │
              ▼
┌──────────────────────────┐
│                          │
│ Stadia Controller Bridge │
│                          │
└─────────────┬────────────┘
              │
              ▼
┌──────────────────────────┐
│                          │
│    Keystroke Actions     │
│                          │
└─────────────┬────────────┘
              │
              ▼
┌──────────────────────────┐
│                          │
│         Ghostty          │
│                          │
└──────────────────────────┘
```

## Profile-Aware Flow (Mermaid)
```mermaid
flowchart TD
    C[Stadia Controller]
    M[macOS GameController]
    B[Bridge Service com.stadia-controller-bridge]
    R[Profile Resolver by Frontmost App]
    G[Ghostty Profile Mappings]
    A[Keystroke Actions]
    H[Ghostty]
    S[Skip No Active Profile]

    C --> M --> B --> R
    R -->|Ghostty| G --> A --> H
    R -->|Other app| S
```

## Profile-Aware Flow (ASCII)
```text
Stadia Controller
  |
  v
macOS GameController
  |
  v
Bridge Service (com.stadia-controller-bridge)
  |
  v
Profile Resolver (frontmost app)
  | Ghostty                    | Other app
  v                            v
Ghostty Profile Mappings     Skip No Active Profile
  |
  v
Keystroke Actions
  |
  v
Ghostty
```
