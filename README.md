# SynologySwiftKit

Swift package for building Synology DSM and Audio Station clients in Swift.

> Status: active development. The package is already usable, but API surface may still change as DSM and Audio Station coverage expands.

## Highlights

- Swift Concurrency-first API (`async/await`, `AsyncStream`)
- Built-in DSM modules: `auth`, `apiInfo`, `quickConnect`, `dsmInfo`, `fileStation`
- Audio Station modules: `album`, `artist`, `composer`, `folder`, `genre`, `info`, `lyrics`, `pin`, `playlist`, `search`, `song`, `stream`, `tagEditor`
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

for await progress in await client.userLogin.login(
    server: "your-quickconnect-id",
    enableHttps: true,
    username: "demo",
    password: "secret"
) {
    switch progress {
    case .connecting:
        print("Connecting...")
    case .authenticating:
        print("Authenticating...")
    case let .completed(result):
        print("Connected:", result.connectionUrl)
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

let albums = try await client.audioStation.album.list(limit: 20)
let songs = try await client.audioStation.song.list(limit: 100)
let playlists = try await client.audioStation.playlist.list(limit: 50)
```

## Dependency Injection

`SynologyClient` accepts custom storage and transport implementations so the package can fit production apps and tests more naturally.

```swift
import SynologySwiftKit

struct MyTransport: HTTPTransporting {
    func send(_ request: URLRequest, timeout: TimeInterval, trustedSSLDomain: String?) async throws -> (Data, URLResponse) {
        fatalError("Provide your own transport")
    }
}

let client = SynologyClient(
    config: SynologyConfig(enableNetworkLogging: false),
    keyValueStorage: UserDefaultsStorage(userDefaults: .standard),
    keyChainStorage: KeyChainStorage(service: "com.example.synology"),
    transport: MyTransport()
)
```

## Session Model

- `SynologyClient` restores persisted session state on initialization when available.
- `clearSession()` clears both in-memory and persisted session state.
- The default auth interceptor automatically attaches session credentials and clears persisted session state when DSM reports an expired session.

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
