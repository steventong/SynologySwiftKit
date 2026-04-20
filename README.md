# SynologySwiftKit

Swift package for building Synology DSM and Audio Station clients in Swift.

> Status: active development. The package is already usable, but API surface may still change as DSM and Audio Station coverage expands.

## Highlights

- Swift Concurrency-first API (`async/await`, `AsyncStream`)
- Built-in DSM modules: `auth`, `system`, `files`
- Audio Station modules: `albums`, `artists`, `composers`, `folders`, `genres`, `info`, `lyricsCatalog`, `pins`, `playlists`, `search`, `songs`, `playback`, `covers`, `tagEditor`
- Higher-level flows for login, connection check, and querying songs
- Customizable transport and storage so integrators can adapt the package to their app architecture

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

## Using Core APIs

```swift
import SynologySwiftKit

let client = SynologyClient()

let albums = try await client.audioStation.albums.list(limit: 20)
let songs = try await client.audioStation.songs.list(limit: 100, libraryScope: .shared)
let playlists = try await client.audioStation.playlists.list(limit: 50, offset: 0)
let smartPlaylist = try await client.audioStation.playlists.createSmart(
    name: "Top Picks",
    definition: SmartPlaylistDefinition(
        scope: .personal,
        matchRule: .all,
        serializedRules: "[]"
    )
)
let songCoverURL = try await client.audioStation.covers.songCoverURL(songID: "music_1", libraryScope: .shared)

print(albums.items.count)
print(songs.total)
print(playlists.items.map(\.name))
print(smartPlaylist.id)
print(songCoverURL)
```

## Dependency Injection

`SynologyClient` accepts custom storage and transport implementations so the package can fit production apps and tests more naturally.

```swift
import SynologySwiftKit

struct MyHTTPClient: HTTPClientProtocol {
    func send(_ request: URLRequest, timeout: TimeInterval, trustedSSLDomain: String?) async throws -> (Data, URLResponse) {
        fatalError("Provide your own transport")
    }
}

let client = SynologyClient(
    config: SynologyConfig(enableNetworkLogging: false),
    keyValueStorage: UserDefaultsStorage(userDefaults: .standard),
    keyChainStorage: KeyChainStorage(service: "com.example.synology"),
    transport: MyHTTPClient()
)
```

## Session Model

- `SynologyClient` restores persisted session state on initialization when available.
- `client.session.clear()` clears both in-memory and persisted session state.
- The default auth interceptor automatically attaches session credentials and clears persisted session state when DSM reports an expired session.

## Public Value Types

- `SynologyPage<Item>`: paged collection result
- `SynologySortDescriptor`: sort field plus sort direction
- `SynologyLibraryScope`: `.all`, `.shared`, `.personal`
- `SynologySession`, `SynologyConnection`, `SynologyCredentials`
- `SmartPlaylistDefinition`: typed input for smart playlist creation

## Stability Notes

- Consume `SynologySwiftKit` from the `develop` branch if you want the latest in-progress changes.
- Public API is still evolving while DSM and Audio Station endpoints are being added.
- If you adopt it in production, pin the exact revision in your app and review changelog-worthy updates before bumping.

## Development

```bash
swift build
swift test
```

## Why This Package Exists

This package was extracted from the DS Music client app so DSM and Audio Station integration code can be reused outside the app itself.
