# SynologySwiftKit

Swift package for building Synology DSM and Audio Station clients in Swift.

> Status: active development. Use the `develop` branch for the latest changes.

## Requirements

- Swift 5.10+
- Xcode 15.4+
- iOS 14+
- macOS 11+
- tvOS 14+
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
    server: "your-quickconnect-id",
    usesHTTPS: true,
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

## Audio Station

```swift
let albums = try await client.audioStation.albums.list(limit: 20)
let songs = try await client.audioStation.songs.list(limit: 100, libraryScope: .shared)
let playlists = try await client.audioStation.playlists.list(limit: 50, offset: 0)
let searchResults = try await client.audioStation.search.list(keyword: "Miles")
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
        frequency: 44100
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

API routes are persisted per login server identity (QuickConnect ID or normalized server address),
not in a global or time-expiring cache. Each password login refreshes routes once; OTP continuation
reuses the discovered endpoint and routes. Session resume and connection recovery reuse cached
routes and validate the SID with `SYNO.DSM.Info.getinfo`, without a preliminary Ping. Missing
routes are discovered on demand; ordinary API requests rejected with 102/103/104 refresh routes
and retry at most once. Diagnostic envelope requests preserve the original response instead.
QuickConnect candidate priority and racing behavior are unchanged.

## Entrypoints

Use one naming system only:

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

These internal DSM APIs are exposed independently; they do not replace the existing
session-validation flow. Availability and semantics must be verified against the NAS.

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

## Audio Station namespace migration

All music APIs now live under `client.audioStation`. Root music aliases and
`client.flows.queryAllSongs` have been removed without compatibility shims.

```swift
let songs = try await client.audioStation.songs.list(limit: 100)
let total = await client.audioStation.queryTotalSongsCount()
for await progress in client.audioStation.queryAllSongs(batchSize: 500, concurrency: 3) {
    // Consume the existing QueryAllSongsProgress events.
    print(progress)
}
```

Move `client.<music API>` to `client.audioStation.<music API>`.
Move `client.flows.queryAllSongs.queryAllSongs(...)` to `client.audioStation.queryAllSongs(...)`,
and `client.flows.queryAllSongs.queryTotalSongsCount()` to `client.audioStation.queryTotalSongsCount()`.
