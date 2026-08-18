# Screenshots

Captures referenced by the root README.

| File | Screen | What it shows |
|---|---|---|
| `01-splash.png` | Splash | Logo and title over the campus background |
| `02-organizations.png` | Home | Organization grid with logos loaded |
| `03-events.png` | Organization events | Upcoming and all events, with past events dimmed |
| `04-event-detail.png` | Event detail | Full event view with the join action |

## Capturing on the iOS simulator

Boot a device, then capture whatever is on screen:

```bash
xcrun simctl boot "iPhone 17"
```

```bash
xcrun simctl io booted screenshot docs/screenshots/02-organizations.png
```

This writes a clean device-resolution PNG with no window chrome, which reads far
better in a README than a cropped desktop screenshot. ⌘S in the Simulator app
works too, though it saves to the Desktop with a long timestamped filename.

The splash screen navigates away after three seconds, so capture it immediately
after launching:

```bash
xcrun simctl terminate booted com.clarknotkent.univents
xcrun simctl launch booted com.clarknotkent.univents
sleep 1
xcrun simctl io booted screenshot docs/screenshots/01-splash.png
```

## Before capturing

- Sign in first so the screens show real organizations and events. Empty states
  make the app look unfinished.
- Confirm organization logos load. A broken-image placeholder in the hero
  screenshot undercuts the whole README.
- The home header shows the signed-in user's name.

## Resizing

A full-resolution iPhone capture runs 0.5–4 MB, which bloats every clone. Scale
them to 400px wide:

```bash
sips --resampleWidth 400 docs/screenshots/*.png
```

Use `--resampleWidth`, **not** `-Z`. `-Z` constrains the longest side, so on a
tall phone capture it would shrink the width to roughly 184px and leave the
image unusably small.
