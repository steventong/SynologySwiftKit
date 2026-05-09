# SynologySwiftKit

Swift package for building Synology DSM and Audio Station clients in Swift.

> Status: active development. Use the `develop` branch for the latest changes.

## Requirements

- Swift 5.10+
- Xcode 15.4+
- iOS 13+
- macOS 10.15+

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

let client = SynologyClient()

for await progress in await client.flows.auth.login(
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

let playbackURL = try await client.audioStation.playback.playbackURL(
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
if let session = client.session.current {
    print(session.sid)
}

if let connection = client.session.connection {
    print(connection.url)
}

client.session.clear()
```

`SynologyClient` restores persisted session state when available. `client.session.clear()` clears both in-memory and persisted session state.

## Custom Storage And HTTP Client

```swift
import SynologySwiftKit

struct MyHTTPClient: HTTPClientProtocol {
    func send(_ request: URLRequest, timeout: TimeInterval, trustedSSLDomain: String?) async throws -> (Data, URLResponse) {
        fatalError("Provide your own HTTP client")
    }
}

let client = SynologyClient(
    config: SynologyConfig(enableNetworkLogging: false),
    keyValueStorage: UserDefaultsStorage(userDefaults: .standard),
    keyChainStorage: KeyChainStorage(service: "com.example.synology"),
    httpClient: MyHTTPClient()
)
```

## Available Modules

| Area | APIs |
| --- | --- |
| DSM | `auth`, `system`, `files` |
| Audio Station | `albums`, `artists`, `composers`, `folders`, `genres`, `info`, `lyricsCatalog`, `pins`, `playlists`, `search`, `songs`, `playback`, `covers`, `tagEditor` |
| Flows | `flows.auth`, `flows.connection`, `flows.library` |

## Development

```bash
swift build
swift test
```
