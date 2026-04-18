# SynologySwiftKit Technical Design

## Purpose

`SynologySwiftKit` is a Swift package for integrating with Synology DSM and Audio Station from Apple platforms.

This document describes the technical architecture of the package, the intended module boundaries, and the design principles used to keep the package suitable for open-source consumption and long-term evolution.

The goals of the design are:

- Provide a small and understandable public entry surface
- Keep transport, storage, and side effects replaceable
- Make core workflows testable without real network or device dependencies
- Isolate Synology-specific protocol details from higher-level application flows
- Allow the package to evolve without forcing unnecessary breaking changes on consumers

## Design Principles

### 1. Public API should be smaller than the implementation

The package may contain many internal building blocks, but consumers should only need a few stable entry points.

Preferred public surface:

- `SynologyClient`
- Feature modules exposed through the client, such as `auth`, `audioStation`, `fileStation`, `quickConnect`
- Domain models and stable error types
- Explicit extension points such as transport, storage, and interceptors

Implementation-detail types should remain internal unless there is a strong external use case.

### 2. Dependency inversion over concrete coupling

Core flows should depend on protocols and capabilities, not on concrete networking or persistence implementations.

This improves:

- testability
- portability
- maintainability
- future replacement of third-party libraries

### 3. Separate orchestration from protocol details

Low-level DSM request construction and response parsing should stay in infrastructure layers.
Higher-level workflows such as login and connection resolution should compose those capabilities rather than reimplement protocol details.

### 4. Configuration and runtime state must be explicit

The package should distinguish between:

- static configuration
- mutable runtime session state
- persistence concerns
- network side effects

This keeps behavior predictable and easier to reason about.

## Architecture Overview

The package is organized around four layers.

### Layer 1: Public Entry Layer

Primary responsibility:

- provide a stable access point for consumers
- assemble dependencies
- expose feature modules and business flows

Main type:

- `SynologyClient`

Expected responsibilities:

- hold package-level configuration
- wire default transport, storage, and interceptors
- expose stable feature APIs
- expose stable business workflows

This layer should avoid leaking request-building details or parser internals.

### Layer 2: Feature and Flow Layer

Primary responsibility:

- expose user-meaningful capabilities
- orchestrate multi-step business workflows

Feature APIs:

- `AuthApi`
- `QuickConnectApi`
- `AudioStationApi`
- `FileStationApi`
- `DsmInfoApi`
- `EncryptionApi`

Business flows:

- `SynologyUserLogin`
- `CheckDeviceConnection`
- `QueryAllSongs`

Feature APIs should encapsulate Synology service boundaries.
Business flows should coordinate multiple APIs into end-to-end workflows.

### Layer 3: Domain Layer

Primary responsibility:

- define stable domain concepts independent from transport details

Examples:

- `SynologyError`
- `SynologyConfig`
- `ConnectionType`
- `ServerType`
- `AuthResult`
- `Song`, `Album`, `Playlist`, `AudioStationInfo`, and other user-facing models

The domain layer should be portable and understandable without needing to inspect the networking layer.

### Layer 4: Infrastructure Layer

Primary responsibility:

- implement networking, persistence, logging, and Synology request protocol handling

Examples:

- `ApiClient`
- `ApiEndpoint`
- `HTTPTransporting`
- `SwiftHttpClientTransport`
- `KeyValueStorage`
- `KeyChainStorage`
- interceptors
- response decoding and internal error mapping

This layer may be internally complex, but it should not dominate the consumer-facing API.

## Dependency Direction

Dependency flow should move in one direction:

`Public Entry Layer` -> `Feature and Flow Layer` -> `Domain Layer`

and

`Feature and Flow Layer` -> `Infrastructure Layer` through protocols or narrow internal contracts

Important constraint:

- higher layers may use lower layers
- lower layers must not import higher-level flow logic
- infrastructure must not own business policy

## Core Runtime Composition

`SynologyClient` acts as the composition root.

At initialization time it should:

- accept package-level configuration
- accept storage implementations for durable and non-durable state
- accept a transport implementation
- create the API client
- register default interceptors when appropriate
- construct feature APIs
- construct higher-level workflows from those APIs

This gives consumers a single stable entry while still preserving internal modularity.

## Main Architectural Building Blocks

### SynologyClient

Role:

- package composition root
- public facade for consumers

Should expose:

- stable feature APIs
- stable flows
- session helpers when they are clearly part of external behavior

Should not expose:

- internal parser details
- low-level raw response structures unless there is a strong use case

### ApiClient

Role:

- low-level DSM request execution engine

Responsibilities:

- resolve endpoints into URLs and requests
- apply interceptors
- send requests through `HTTPTransporting`
- decode response payloads
- map transport and protocol failures into package-level errors

It should remain an internal implementation detail wherever possible.

### Feature APIs

Role:

- represent a bounded Synology service area

Example:

- `AuthApi` handles login/logout credential-related requests
- `QuickConnectApi` resolves QuickConnect addresses
- `AudioStationApi` groups music-related capabilities

Feature APIs should stay focused and avoid accumulating unrelated orchestration logic.

### Business Flows

Role:

- coordinate multiple capabilities into end-to-end user workflows

Examples:

- login flow
- connection verification
- full-song enumeration

These flows are appropriate places for sequencing, retries, progress streaming, and state transitions.

### Storage Abstractions

Current package design distinguishes:

- key-value storage for non-sensitive cache and lightweight persisted state
- keychain storage for credentials and session-sensitive values

Design requirement:

- consumers must be able to replace storage implementations
- flows must reuse injected storage instead of creating hidden default instances

### Transport Abstraction

`HTTPTransporting` is the package boundary for outbound networking.

Design requirement:

- third-party HTTP client choices must stay behind the transport boundary
- the rest of the package should not depend directly on `SwiftHttpClient`

This prevents the entire package from being architecturally coupled to one networking library.

## State Model

The runtime state in the package should be explicit.

### Static Configuration

Represented by `SynologyConfig`.

Examples:

- timeout settings
- logging behavior
- cache policy defaults

This state should be immutable after initialization where possible.

### Runtime Session State

Examples:

- current connection
- current session SID and DID
- derived reachable endpoint

This state belongs to the running client and may also be mirrored to persistent storage.

### Persisted State

Examples:

- saved credentials
- last known connection
- cached API info
- cached Audio Station info

Persistence should not be hidden in arbitrary modules.
The source of persisted data should remain clear and replaceable.

## Concurrency Model

The package uses Swift Concurrency and should continue to align with it consistently.

Current guidance:

- use `actor` only where mutable shared state or serialized access is genuinely required
- mark public domain types `Sendable` when they are intended to cross concurrency boundaries
- avoid mixing ad hoc thread-safety strategies unless necessary
- keep async workflows explicit through `async` functions or `AsyncStream`

Concurrency correctness should be part of API design, not an implementation afterthought.

## Error Model

The external error surface should stay unified around `SynologyError`.

Internal layers may decode or interpret raw protocol errors, but those details should be normalized before escaping to consumers.

Preferred error categories:

- network/transport failures
- authentication failures
- session expiration
- API/business failures

Why this matters:

- consumers can write predictable error handling
- internal transport or parsing changes do not force public API churn

## Logging and Observability

Logging is part of runtime architecture, not a debugging afterthought.

Requirements:

- logging should be centrally configurable
- package logs should be safe to disable
- logging implementation should not leak through feature APIs
- logs should help trace request lifecycle and flow-level decisions

Future improvement area:

- add structured request identifiers or flow correlation metadata for complex multi-step operations

## Testing Strategy

Architecture should support three testing scopes.

### Unit Tests

Target:

- endpoint construction
- request interception
- error mapping
- storage behavior
- pure helpers and utilities

Requirements:

- no real network
- no real DSM dependency

### Flow Tests

Target:

- login flow behavior
- connection resolution behavior
- session restore and invalidation behavior

Requirements:

- mock API client
- deterministic storage
- explicit success and failure scenarios

### Integration Tests

Target:

- end-to-end package behavior against a real or controlled Synology environment

These tests are useful but should not be required for every contributor just to validate core package correctness.

## Public API Design Guidance

When deciding whether something should be public, use these checks:

### Make it public if:

- consumers must implement it
- consumers must inject it
- consumers must catch or interpret it
- it represents a stable domain concept

### Keep it internal if:

- it only supports request assembly
- it only supports decoding internals
- it exists only to adapt a third-party dependency
- changing it should not be considered a breaking change

Examples of types that should usually remain internal unless proven otherwise:

- raw Synology response wrappers
- low-level error mappers
- internal constants
- helper-only transport encoding types

## Recommended Evolution Direction

The package should continue evolving toward:

- a tighter public API surface
- clearer separation between feature APIs and infrastructure
- more protocol-driven orchestration boundaries
- stronger automated tests around flows and session behavior
- better documentation for supported DSM and Audio Station capabilities

## Non-Goals

The package is not trying to be:

- a generic HTTP framework
- a full application architecture framework
- a UI framework

The package should remain focused on Synology integration and related workflows.

## Suggested Repository Structure

One maintainable direction for the repository is:

```text
Sources/
  SynologySwiftKit/
    Client/
      SynologyClient.swift
    Domain/
      Models/
      Errors/
      Config/
    Features/
      Auth/
      QuickConnect/
      AudioStation/
      FileStation/
    Flows/
      SynologyUserLogin/
      CheckDeviceConnection/
      QueryAllSongs/
    Infrastructure/
      Transport/
      Storage/
      Logging/
      ApiCore/
      Interceptors/
    Resources/

Tests/
  SynologySwiftKitTests/
    Unit/
    Flows/
    Integration/
```

This does not need to happen all at once, but it is a good long-term architectural target.

## Architectural Review Checklist

Use this checklist before expanding the package:

- Does the new feature belong in an existing feature module or require a new one?
- Is the new type really part of the public contract?
- Can the behavior be tested without real DSM access?
- Does the flow depend on protocols instead of concrete infrastructure?
- Does the change keep request protocol details below the public API boundary?
- Will consumers understand where to use the new API without reading internal implementation files?

## Summary

The intended architecture of `SynologySwiftKit` is:

- one clear public entry point
- focused feature modules
- explicit business workflows
- a stable domain layer
- replaceable infrastructure
- a controlled and intentional public API

This is the architecture shape most likely to support long-term open-source adoption, safe refactoring, and external contribution.
