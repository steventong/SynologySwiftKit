# Changelog

All notable changes to `SynologySwiftKit` should be documented in this file.

The package is still under active development and is commonly consumed from the `develop` branch, so entries are grouped as practical release notes instead of strict version tags for now.

## Unreleased

- Improved package integration for external consumers by making `SynologyClient` configurable with custom transport, storage, and startup interceptors.
- Reused injected storage consistently across login and connection flows instead of creating hidden default instances internally.
- Wired `SynologyConfig.enableNetworkLogging` into the package logger so the configuration now affects runtime behavior.
- Fixed the test target so `swift test` passes again.
- Added regression tests for auth interception and codable storage behavior.
- Rewrote the README with installation, quick start, dependency injection, and session model guidance.
- Reduced a few implementation-detail symbols back to internal visibility to keep the public API more focused.
