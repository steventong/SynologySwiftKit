# SynologySwiftKit

Swift package for building Synology DSM and Audio Station clients in Swift.

## Requirements

- Swift 5.10+
- Xcode 15.4+
- iOS 14+
- macOS 11+
- tvOS 14+
- watchOS 10+
- visionOS 1+

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/steventong/SynologySwiftKit.git", branch: "develop")
]
```

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "SynologySwiftKit", package: "SynologySwiftKit")
        ]
    )
]
```

## Quick Start

```swift
import SynologySwiftKit

let client = SynologyClientFactory.make()

for await progress in client.flows.userLogin.login(
    sessionName: .audioStation,
    server: "your-quickconnect-id",
    username: "demo",
    password: "secret"
) {
    switch progress {
    case .connecting:
        print("Connecting...")
    case .authenticating:
        print("Authenticating...")
    case let .completed(result):
        print("Connected:", result.connection.url)
    case .otpRequired:
        print("OTP required")
    case let .failed(message), let .invalidSession(message):
        print("Login failed:", message)
    }
}
```

## File Station sharing links

`client.dsmInfo.timeZoneInfo()` reads `SYNO.Core.Region.NTP.get` and `listzone` (v1). It joins the configured opaque key to the NAS's own option list and formats the numeric `offset` as `displayPrefix` (for example `GMT+08:00`). It does not recognize city names or keep a local alias catalog. The prefix matches the DSM dropdown; it is not a prediction of the offset at a future expiry date. `currentTimeZone` derives the current effective offset from the same NAS clock response's date/time fields and epoch timestamp, including any current daylight saving, for calendar-date calculations. `timeZone()` returns this current offset snapshot; neither API supplies future transition rules. Permission failures, malformed clock data, missing or duplicate options and invalid offsets fail explicitly without falling back to the device zone. This DSM internal endpoint may be restricted for non-administrator accounts.

After signing in with the `.fileStation` session, use `client.files` to manage the current user's public links:

```swift
let page = try await client.files.listSharingLinks(refreshStatus: true)
let existing = page.links.filter { $0.path == "/public/demo.pdf" }
let link = try await client.files.createSharingLink(
    path: "/public/demo.pdf", expirationDate: "2026-12-31"
)
let details = try await client.files.sharingLink(id: link.id)
try await client.files.updateSharingLink(id: link.id, expirationDate: "2027-01-01", password: "example")
try await client.files.deleteSharingLink(id: link.id)
```

`expirationDate` is a Gregorian `YYYY-MM-DD` date interpreted by the NAS; omit it for a permanent link. Creation also accepts an optional password. The SDK JSON-encodes paths, IDs and dates, checks per-link creation errors, and returns DSM's public URL. Revoking a link does not delete its file. After an uncertain mutation result, list links again before retrying creation. `listSharingLinks` supports offset/limit; zero limit requests all links. These methods use `SYNO.FileStation.Sharing` v3.

For `updateSharingLink`, omitted fields stay unchanged, `expirationDate: "0"` makes the link permanent, and `password: ""` removes the password. Passwords are limited to 16 characters. Editing preserves the existing URL; use `sharingLink(id:)` to read the updated metadata. DSM returns whether a password exists, not the password itself.

## Login Session Name

Pass a `SynologySessionName` explicitly when logging in. The enum supports `.audioStation`,
`.fileStation`, and `.videoStation`, whose raw values are the DSM protocol session names.
This is a server-side protocol value used for application session/permission checks, not your
SDK/product name or a session ID. It must match the target DSM application; an arbitrary name
can cause `SYNO.API.Auth.login` to fail with code 402 (permission denied).
Kit does not provide a default. Direct `client.auth.login` calls also require `sessionName`.

When `.otpRequired` is emitted, call the same `login` method again with the credentials and
`otpCode`. Each call discovers the connection and refreshes API routes through the regular
login flow.

Use the same session name for password login, OTP retries and renewal:

```swift
let progress = client.flows.userLogin.resume(sessionName: .audioStation)
let renewal = client.flows.userLogin.relogin(sessionName: .audioStation)
```

The host supplies the name again after relaunch; Kit does not infer it from saved credentials.

## Audio Station

```swift
let albums = try await client.audioStation.albums.list(limit: 20)
let songs = try await client.audioStation.songs.list(limit: 100, libraryScope: .shared)
let playlists = try await client.audioStation.playlists.list(limit: 50, offset: 0)
let searchResults = try await client.audioStation.search.list(keyword: "Miles", libraryScope: .shared)
```

## Playlists

```swift
let playlist = try await client.audioStation.playlists.create(
    name: "Favorites",
    libraryScope: .personal,
    songIDs: ["music_1", "music_2"]
)

try await client.audioStation.playlists.addSongs(
    id: playlist.id,
    songIDs: ["music_3"]
)
```

## Covers And Playback

```swift
let coverURL = try await client.audioStation.covers.songCoverURL(
    songID: "music_1",
    libraryScope: .shared
)

let playbackURL = try await client.audioStation.stream.playbackURL(
    for: SongPlaybackSource(
        id: "music_1",
        path: "/music/demo.mp3",
        bitrate: 320000,
        frequency: 44100,
        fileExtension: ".mp3"
    ),
    quality: .ORIGINAL
)
```

## Session

```swift
client.configureConnection(
    type: .custom_domain,
    url: "https://nas.local",
    sid: "existing-sid",
    did: "existing-device-id"
)

let restoredClient = SynologyClientFactory.makeWithExistingSession(
    connectionType: .custom_domain,
    url: "https://nas.local",
    sid: "existing-sid"
)

if let session = client.session.current {
    print(session.sid)
}

if let connection = client.session.connection {
    print(connection.url)
}

client.session.clear()
```

`SynologyClient` restores persisted session state when available. `client.session.clear()` clears both in-memory and persisted session state.

API routes are persisted per login server identity (QuickConnect ID or normalized server address).
Each password login, including an OTP retry through the login flow, discovers the connection
and refreshes routes once. Session resume and connection recovery reuse cached
routes and validate the SID with `SYNO.DSM.Info.getinfo`. Missing
routes are discovered on demand; ordinary API requests rejected with 102/103/104 refresh routes
and retry at most once. Diagnostic envelope requests preserve the original response instead.
Standard API requests use their declared protocol version. A version outside the server's
advertised range fails with code 104. Route discovery can refresh once before the request fails.

## Entrypoints

Access APIs and flows through these properties:

- grouped modules: `client.auth`, `client.system`, `client.audioStation`, `client.files`, `client.session`, `client.flows`
- direct system API names: `client.quickConnect`, `client.dsmInfo`, `client.encryption`
- Audio Station APIs: `client.audioStation.songs`, `client.audioStation.albums`, `client.audioStation.folders`, `client.audioStation.search`, and other music APIs
- music batch queries: `client.audioStation.queryAllSongs(batchSize:concurrency:)`, `client.audioStation.queryTotalSongsCount()`
- task flows: `client.flows.userLogin`, `client.flows.connectionCheck`, `client.flows.connection`
- `client.files`: File Station file operations

## Request Interceptors

```swift
struct HeaderInterceptor: SynologyRequestInterceptor {
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        request.setValue("1", forHTTPHeaderField: "X-Trace")
        return request
    }
}

client.addInterceptor(HeaderInterceptor())
```

Use interceptors for logging, tracing, diagnostics, and host-application headers. Authentication is handled by the SDK session pipeline.

## Custom Storage And HTTP Client

```swift
import SynologySwiftKit
import SwiftHttpClient

let factory: SynologyHTTPClientFactory = { timeout, trustedSSLDomain in
    HTTPClient(timeout: timeout, trustedSSLDomain: trustedSSLDomain)
}

let client = SynologyClient(
    config: SynologyConfig(
        enableNetworkLogging: true,
        logDestination: .systemAndHandler,
        logHandler: { record in
            AppLogger.debug("[SynologySwiftKit] \(record.message)")
        }
    ),
    keyValueStorage: UserDefaultsStorage(userDefaults: .standard),
    keyChainStorage: KeyChainStorage(service: "com.example.synology"),
    httpClientFactory: factory
)
```

## Logging

`SynologySwiftKit` uses Apple Unified Logging by default.

```swift
let client = SynologyClientFactory.make(
    config: SynologyConfig(
        logDestination: .systemAndHandler,
        logHandler: { record in
            AppLogger.debug("[SynologySwiftKit][\(record.level)] \(record.message)")
        }
    )
)
```

Use `.system` to keep only OS logging, `.handler` to forward only to the host app, or `.systemAndHandler` to do both. The handler is optional.

## Available Modules

| Area | APIs |
| --- | --- |
| Grouped modules | `auth`, `system`, `audioStation`, `files`, `session`, `flows` |
| Direct system API names | `quickConnect`, `dsmInfo`, `encryption` |
| Audio Station | `audioStation.songs`, `audioStation.albums`, `audioStation.folders`, `audioStation.search`, and other music APIs |
| Task flows | `userLogin`, `connectionCheck`, `connection` |

## Development

```bash
swift build
swift test
```

## DSM Core Read APIs

`client.system.desktopTimeout` and `client.system.normalUser` expose DSM read APIs.
Access depends on the NAS's permissions and supported APIs.

```swift
let timeout = try await client.system.desktopTimeout.check()
let user = try await client.system.normalUser.get()

// Explicit SID requests use only the supplied SID, without ambient session cookies.
let check = try await client.system.desktopTimeout.check(sid: sid)
let profile = try await client.system.normalUser.get(sid: sid)
```

Both return `DSMReadResponse` with `success`, optional `data` (JSON fields), and
optional `error.code` / `error.errors`. API failures are returned, not automatically
classified as authentication failures, and do not clear the active session.
Transport, API-discovery and decoding failures throw. `success: true` without
`data` is supported. The response is Codable for display; callers should redact
credentials and personal fields before exporting diagnostics.

## Audio Station batch queries

`client.audioStation` provides song totals and batched song queries.

```swift
let songs = try await client.audioStation.songs.list(limit: 100)
let total = await client.audioStation.queryTotalSongsCount()
for await progress in client.audioStation.queryAllSongs(batchSize: 500, concurrency: 3) {
    // Handle each QueryAllSongsProgress event.
    print(progress)
}
```
