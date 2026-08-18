# Screenshots

Drop the captures referenced by the root README here, using these exact names:

| File | Screen | What to show |
|---|---|---|
| `01-splash.png` | Splash | Logo and title over the campus background |
| `02-login.png` | Login | Both sign-in options visible; **do not type a real password** |
| `03-organizations.png` | Home | Organization grid with logos loading correctly |
| `04-events.png` | Organization events | An organization with several events listed |
| `05-event-detail.png` | Event detail | Full event view before joining |
| `06-joined.png` | Event detail | The same event after joining, showing the joined state |

## Capturing on the iOS simulator

Boot a device and take a shot straight to this folder:

```bash
xcrun simctl boot "iPhone 17 Pro"
```

```bash
xcrun simctl io booted screenshot docs/screenshots/03-organizations.png
```

This produces a clean device-resolution PNG with no window chrome, which is why
it looks better in a README than a cropped desktop screenshot.

## Before capturing

- Sign in with a real account so the screens show actual organizations and
  events. Empty states make the app look unfinished.
- Check that organization logos load. A broken-image placeholder in the hero
  screenshot undercuts the whole README.
- The header displays the signed-in user's name. Use an account whose displayed
  name you are comfortable publishing, or crop it.

## Size

Full-resolution iPhone screenshots run 1–3 MB each, and six of them noticeably
inflates a clone. Resizing to roughly 400px wide keeps them sharp in the README
table while cutting each to tens of kilobytes:

```bash
sips -Z 400 docs/screenshots/*.png
```

`sips` ships with macOS, so no extra tooling is needed.
