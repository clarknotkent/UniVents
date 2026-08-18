# Security model

How access control works in this project, and why it is built this way.

## The threat model

The Firebase API key in `lib/firebase_options.dart` is **not a secret**. It ships
inside every copy of the app, and anyone can extract it from a binary or read it
in this repository. Google documents these keys as public identifiers.

The practical consequence: anyone can talk to this project's Firestore directly
with a script — no app, no login screen, no Dart code involved.

```
POST https://firestore.googleapis.com/v1/projects/<project>/databases/(default)/documents/...?key=<public key>
```

So every check written in Dart is advisory. The `@addu.edu.ph` test in
`login_screen.dart` runs *after* Firebase has already authenticated the user.
The `'role': 'student'` value is simply what the client chose to send. Neither
constrains an attacker who never runs the app.

**`firestore.rules` is the enforcement boundary.** It runs on Google's servers
and cannot be bypassed. Every client-side check is re-asserted there.

## Rules design

### Default deny

Every collection not named explicitly is unreachable:

```
match /{document=**} {
  allow read, write: if false;
}
```

New collections fail closed until a rule is written for them deliberately.

### Membership requires a *verified* university address

```
function isUniversityMember() {
  return isSignedIn()
         && request.auth.token.email != null
         && request.auth.token.email_verified == true
         && request.auth.token.email.lower().matches('[^@]+@addu[.]edu[.]ph');
}
```

Two details carry the weight here.

**`email_verified` is not optional.** The app has no sign-up screen, but Firebase
Auth's REST `signUp` endpoint is reachable by anyone holding the public API key,
and Firebase does not confirm ownership of an address at sign-up. Without this
check, an outsider could register `anyone@addu.edu.ph` — an address they do not
control — and satisfy the domain test. Google Sign-In sets `email_verified` to
true because Google has already proven ownership; an unverified password account
cannot pass.

**The regex is anchored deliberately.** `matches()` is RE2 with full-string
semantics, so the pattern must describe the whole address. The local part is
`[^@]+` rather than `.*` because a trailing-only pattern like
`.*@addu[.]edu[.]ph` would also accept `someone@evil.com@addu.edu.ph` — `.*`
happily swallows an extra `@`. Dots are written `[.]` so they match literal dots
rather than any character.

### Roles cannot be self-granted

The original rule was:

```
allow write: if request.auth != null && request.auth.uid == userId;
```

A single `write` covers create *and* update, so any signed-in student could run:

```dart
FirebaseFirestore.instance.collection('users').doc(myUid).update({'role': 'admin'});
```

The rule checked *who* was writing and never *what*. The replacement splits the
operations:

```
allow create: ... && request.resource.data.role == 'student';
allow update: ... && request.resource.data.get('role', '') == resource.data.get('role', '');
```

Create pins the role to `student`. Update requires the new value to equal the
existing one, freezing `role`, `uid`, and `email` from the client's side. Real
role changes belong in a Cloud Function using the Admin SDK, which bypasses
rules entirely, or in custom auth claims.

`request.resource` is the document *after* the write; `resource` is the document
*as it currently exists*. Comparing the two is what makes a field immutable.

`.get(field, default)` is used instead of bare field access because reading a
missing field raises an error in Firestore rules, which denies the entire
request — a legacy document lacking one of these fields would otherwise lock its
owner out of profile updates.

### Attendance is owner-scoped

```
match /attendees/{attendeeId} {
  allow read:   if isOwner(attendeeId);
  allow create: if isOwner(attendeeId) && ... && request.resource.data.userId == request.auth.uid;
  allow update: if false;
  allow delete: if isOwner(attendeeId);
}
```

The document ID is pinned to the caller's UID, so nobody can register — or
un-register — anyone else.

Read is owner-only rather than member-wide because each attendee document stores
`userEmail` and `userName`. A member-wide read would let any student enumerate
the email address of everyone attending an event. The app only ever reads its
own document, so nothing is lost. A public attendee list or count would need
either a relaxed rule here or, better, a counter field maintained by a Cloud
Function.

`update` is closed because the app joins with `set()` and leaves with `delete()`.
There is no edit path to permit.

### Content collections are read-only

`organizations` and `events` are curated from the Firebase console. The app never
writes to them, so `allow write: if false`. If a write path is added later, the
rule must be opened deliberately.

## Defence in depth on the client

`splash_screen.dart` re-checks eligibility when restoring a session. Routing on
`currentUser != null` alone would let any account that ever authenticated back in
on every subsequent launch, because the domain gate lives on the login screen and
never runs on that path. Sessions that fail the check are signed out.

This is a usability measure, not a security boundary — the rules are what
actually deny such a session any data.

## What is and is not sensitive

| Item | Sensitive? | Reasoning |
|---|---|---|
| Firebase API keys | No | Public client identifiers, present in every binary |
| OAuth client IDs | No | Public by design |
| Signing certificate SHA-1 | No | A fingerprint, not a key; cannot sign anything |
| Contents of `.env` | No | Bundled as an app asset; extractable from the binary |
| Release signing keystore | **Yes** | Not yet created; never commit it |
| Service account JSON | **Yes** | Not used by this project |

### On `.env`

`.env` is gitignored, which can create a false impression that it is a secret
store. It is not. `flutter_dotenv` loads it as a **bundled asset**, so every
value ships inside the app and can be recovered from a downloaded binary as
easily as the API keys in `firebase_options.dart`.

It is gitignored so that each environment supplies its own configuration, not
because the contents are confidential — which is why `.env.example` is committed
with real, working values.

The rule of thumb for any client application: if a value must be unknowable to
the user, it cannot live in the client at all. It belongs behind a server-side
boundary such as a Cloud Function using the Admin SDK.

The meaningful hardening for public keys is **restriction**, not rotation. In the
Google Cloud console, each key can be limited to a specific Android package plus
signing SHA-1, an iOS bundle ID, or a set of web origins, and to a specific list
of APIs. A restricted key only works from the real app.

## Operational notes

Rules are inert until deployed:

```bash
firebase deploy --only firestore:rules --project <your-project-id>
```

A project left in Firebase's test mode (`allow read, write: if true`) is fully
open to the internet regardless of what this repository contains. Verify the
deployed state rather than assuming it — an unauthenticated request with only the
public API key should be rejected:

```
https://firestore.googleapis.com/v1/projects/<project>/databases/(default)/documents/organizations?key=<public key>
```

A `403 PERMISSION_DENIED` means the rules are live. Returned JSON means the
database is open.

Requiring `email_verified` locks out password accounts created in the Firebase
console, which default to unverified. Mark them verified under
Authentication → Users, or use Google Sign-In.
