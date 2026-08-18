# univents_app

Flutter application source for UNIVENTS.

See the [repository README](../README.md) for an overview, setup instructions,
and known limitations, and [docs/SECURITY.md](../docs/SECURITY.md) for the access
control model.

## Quick reference

```bash
flutter pub get                  # install dependencies
flutter run                      # run on the selected device
flutter devices                  # list targets (use the device id with -d)
flutter analyze                  # static analysis
flutter build apk --debug        # Android
flutter build ios --simulator    # iOS simulator
flutter build web                # web
```

Firebase configuration is generated — regenerate it with `flutterfire configure`
rather than editing `lib/firebase_options.dart` by hand.

Security rules live in [`firestore.rules`](firestore.rules) and take effect only
once deployed:

```bash
firebase deploy --only firestore:rules --project <your-project-id>
```
