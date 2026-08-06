# Logging

## Purpose

Spot uses one structured logging path for console and DEBUG device-file output.

## Pattern

Define events in a `SpotLog` enum under `Spot/Models/Logs/`. Every log file owns a
stable component tag, severity, and message:

```swift
enum AuthServiceLogs: SpotLog {
    case sessionRefreshFailed

    var tag: String { "AuthService" }
    var level: LogLevel { .error }
    var message: String { "Session refresh failed" }
}
```

Emit only through `SpotLogger`:

```swift
SpotLogger.log(
    AuthServiceLogs.sessionRefreshFailed,
    details: [
        "responseCode": 401,
        "errorMessage": "Session expired",
        "retrying": true
    ]
)
```

Console and file output use the same format:

```text
AuthService Session refresh failed
[
    errorMessage: "Session expired"
    responseCode: 401
    retrying: true
]
```

The logger does not print the source filename, line, function, severity label, or
an additional logger prefix. Apple Unified Logging still retains severity
metadata for Xcode filtering.

## Root logging profiles

`LoggingConfig` reads one `loggingProfile` integer from `UserDefaults`. DEBUG
builds expose it under Settings → Debug → Logging.

| Value | Profile | Behavior |
|---|---|---|
| 0 | Errors only | Error events |
| 1 | Info + errors | Info and error events |
| 2 | Debug + info + errors | All severities except known high-frequency debug tags |
| 3 | UI only | Events emitted directly under `Spot/Views` |
| 4 | All logs | Every event, including high-frequency diagnostics |

Profile 2 suppresses debug events from analytics, deep links, feed events and
image hydration, location, map loading/markers/views, search, and Spot cards.
Errors and info from those components still appear. Add a tag to that
suppression set only when its debug events are demonstrably high frequency.

Non-DEBUG builds always use profile 0 regardless of saved DEBUG settings.
`Spot/Config/LoggingDefaults.plist` controls the first-launch DEBUG default.

## Device file

In a DEBUG build, emitted logs are also appended to:

```text
Documents/spot-debug.txt
```

`LoggingConfig.configure()` seeds the file with a session header so Files shows
the Spot folder even before the first structured log. The file is protected
until first device unlock, rotates at 1 MB, and retains three archives. File
writing is compiled out of release builds.

The Debug target’s `UIFileSharingEnabled` and
`LSSupportsOpeningDocumentsInPlace` build settings expose the Documents
directory at Files → On My iPhone → Spot and through Finder when the device is
connected to a Mac. Release builds do not expose Documents. Log files are
excluded from device backups.

## Privacy and noise rules

`SpotLogger` centrally redacts credentials, tokens, emails, queries, precise
coordinates, paths, and full URLs. User and Spot identifiers are shortened.
Error text is scrubbed for embedded emails and URLs.

Call sites must still follow these rules:

- Do not pass passwords, access tokens, authorization headers, or secrets.
- Prefer response codes and stable error categories over raw server payloads.
- Do not log events on every render, animation frame, map pan, or location fix
  unless the event is debug severity and profile 4 is required.
- Consolidate multiple messages for one operation into one event with details.
- Use stable tags and messages so logs remain searchable.

## Implementation

- `Spot/Utils/SpotLogger.swift`
- `Spot/Utils/LoggingConfig.swift`
- `Spot/Config/LoggingDefaults.plist`
- `Spot/Models/Logs/`
- `SpotTests/SpotLoggerTests.swift`
