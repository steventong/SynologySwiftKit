# SynologySwiftKit

Swift package for building Synology DSM and Audio Station clients in Swift.

> Status: active development. Use the `develop` branch for the latest changes.

## Requirements

- Swift 5.10+
- Xcode 15.4+
- iOS 13+
- macOS 10.15+
- tvOS 13+
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
let albums = try await client.albums.list(limit: 20)
let songs = try await client.songs.list(limit: 100, libraryScope: .shared)
let playlists = try await client.playlists.list(limit: 50, offset: 0)
let searchResults = try await client.search.list(keyword: "Miles")
```

## Playlists

```swift
let playlist = try await client.playlists.create(
    name: "Favorites",
    libraryScope: .personal,
    songIDs: ["music_1", "music_2"]
)

try await client.playlists.addSongs(
    id: playlist.id,
    songIDs: ["music_3"]
)
```

## Covers And Playback

```swift
let coverURL = try await client.covers.songCoverURL(
    songID: "music_1",
    libraryScope: .shared
)

let playbackURL = try await client.stream.playbackURL(
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

## Entrypoints

Use one naming system only:

- grouped modules: `client.auth`, `client.system`, `client.audioStation`, `client.files`, `client.session`, `client.flows`
- direct API names: `client.quickConnect`, `client.dsmInfo`, `client.encryption`, `client.songs`, `client.albums`, `client.artists`, `client.composers`, `client.genres`, `client.folders`, `client.playlists`, `client.pins`, `client.lyrics`, `client.search`, `client.covers`, `client.stream`, `client.tagEditor`
- task flows: `client.flows.userLogin`, `client.flows.checkDeviceConnection`, `client.flows.queryAllSongs`
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
    config: SynologyConfig(enableNetworkLogging: false),
    keyValueStorage: UserDefaultsStorage(userDefaults: .standard),
    keyChainStorage: KeyChainStorage(service: "com.example.synology"),
    httpClientFactory: factory
)
```

## Available Modules

| Area | APIs |
| --- | --- |
| Grouped modules | `auth`, `system`, `audioStation`, `files`, `session`, `flows` |
| Direct API names | `quickConnect`, `dsmInfo`, `encryption`, `songs`, `albums`, `artists`, `composers`, `genres`, `folders`, `playlists`, `pins`, `lyrics`, `search`, `covers`, `stream`, `tagEditor` |
| Task flows | `userLogin`, `checkDeviceConnection`, `queryAllSongs` |

## Development

```bash
swift build
swift test
```
