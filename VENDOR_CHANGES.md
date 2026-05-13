# Invyte patches on top of upstream convex_flutter

This fork sits on top of [jkuldev/convex_flutter](https://github.com/jkuldev/convex_flutter)
`main` (post-PR #17 — `convex` 0.10.3 + `Map<String, dynamic>` args). Each section
below corresponds to a discrete commit on this branch; refer to `git log` for
exact contents. Upstream issue tracking Android WSS failure:
[#18](https://github.com/jkuldev/convex_flutter/issues/18).

## Cargokit (`cargokit/`)

### Skip debug x86 + x86_64 force-add on Android

**cargokit/gradle/plugin.gradle** — upstream mirrors `flutter.gradle` by
force-adding `android-x86` and `android-x64` to the debug target list, so
`cargo build` runs for three architectures even when the connected device is
arm64. Invyte ships arm64-v8a only (see `app/android/app/build.gradle.kts`
`ndk.abiFilters`), and dev/test happens on physical arm64 devices via the
WSL2→Windows ADB bridge. The extra cross-compiles added ~60–90s per debug
iteration. The block is replaced with a comment; to re-enable emulator builds,
restore the upstream lines or pass `--target-platform=android-x64`.

## Rust client (`rust/`)

### TLS: disable default `native-tls-vendored` feature

**Cargo.toml** — `convex` dependency changed to `default-features = false`.

The `convex` crate's default features enable `native-tls-vendored`, which compiles
OpenSSL from source. When combined with our explicit `rustls-tls-webpki-roots`
feature, both TLS backends are linked into `tokio-tungstenite`. At runtime,
`tokio-tungstenite` prefers `native-tls` when both are present — and vendored
OpenSSL cannot resolve CA certificates on Android, causing WSS handshakes to fail
silently (the connection stays in "connecting" forever).

Setting `default-features = false` ensures only `rustls` (pure Rust, bundled
Mozilla CA certs) is compiled. No OpenSSL dependency.

### Logging: tracing → logcat bridge

**Cargo.toml** — added `tracing` with `log` feature.

**lib.rs** — replaced `println!` (goes to `/dev/null` on Android) with
`log::debug!` / `log::error!` calls. The `tracing` crate's `log` feature
causes tracing events (used by the Convex SDK for connection errors, backoff,
and reconnect diagnostics) to automatically fall through to the `log` crate
when no tracing subscriber is installed. `android_logger` then forwards
everything to logcat.

Log level is controlled by the `verbose_logging` flag passed from Dart's
`ConvexConfig.debugLogging`: verbose = Debug (all messages), normal = Warn
(only warnings and errors).

### Verbose logging flag

**lib.rs** — `MobileConvexClient::new()` accepts a `verbose_logging: bool`
parameter that controls `android_logger` max level.

**lib/src/convex_config.dart** — added a `debugLogging` field on
`ConvexConfig` (defaults to `false`) so consumers can drive verbose mode
from `kDebugMode`. The Dart wrapper (`NativeConvexClient`) passes it
through to the Rust constructor and gates all informational `debugPrint`
calls behind it. Error-level logs are always printed.

### Cross-transport number normalisation

**lib/src/utils.dart** — added `normalizeJsonNumbers()` helper.

Dart's `jsonDecode` preserves `1` (int) vs `1.0` (double). The web client
delivers integers for whole numbers, but the Rust FFI client serialises
all Convex `Float64` values with a decimal point. This mismatch causes
`as int` casts in consumer DTOs to throw on mobile. The native client now
post-processes results through `normalizeJsonNumbers` so consumers see
the same Dart types regardless of transport.

### Bump Convex SDK

**Cargo.toml** — `convex` bumped from `0.7.0` to `0.10.4`.

- `0.10.3` (upstream PR #331): newer protocol support, `WebSocketState`
  callback API, reconnect-loop fix that prevented `Base version 0 passed up
  doesn't match the current version 1` after lifecycle interruptions.
- `0.10.4`: fix for memory leak in query subscriptions
  ([convex-rs#15](https://github.com/get-convex/convex-rs/issues/15)) —
  `BaseConvexClient` retained cached `FunctionResult` entries after the final
  unsubscribe. Long-lived sessions with many distinct subscriptions (Invyte's
  exact shape: events, chat, live) accumulated ~8 KB per query result. Also
  raises Rust MSRV to 1.85; pulls in `imbl` 7.0 (major bump) and new
  transitives `safe_arch` + `wide`. Mirrors upstream PR #20.

## Web client (`lib/src/impl/convex_client_web.dart`)

All patches listed in the file header comment (patches 1–9):

### 1. Auth message format

`_sendAuthMessage` — corrected `Authenticate` message to use the
`tokenType`/`value`/`baseVersion` structure expected by the Convex protocol.

### 2. Sign-out sends null token

`setAuth` — pass `null` instead of `''` for sign-out so `tokenType:"None"` is
sent to the server.

### 3. Message queueing during connect

`_sendMessage` — queue messages when the WebSocket is still in `CONNECTING`
state. Queued messages are flushed automatically once the connection opens.
Fixes a startup race where operations issued before the handshake completed
were silently lost.

### 4. Void-returning function results

`_handleMutationResponse` / `_handleActionResponse` — check the `success` flag
before treating a `null` result as an error. Void-returning Convex functions
legitimately return `null`.

### 5. Structured error types

`_handleMutationResponse` / `_handleActionResponse` — emit `ClientError`
(`convexError` or `serverError` variants) instead of generic `Exception`,
matching the error types produced by the native FFI client.

### 6. Separate identity version counter

`_sendAuthMessage` — use a dedicated `_identityVersion` counter (not
`_querySetVersion`) for the `Authenticate` message's `baseVersion`. The Convex
protocol tracks query-set and identity versions independently.

### 7. Deliver null subscription values

`_handleTransition` — forward `null` `QueryUpdated` values to subscribers
(e.g. a query returning `null` for an unauthenticated user). Previously only
non-null values were delivered.

### 8. Query-set version sync on reconnect

`onopen` handler — sync `_querySetVersion` after flushing queued
`ModifyQuerySet` messages so the local counter stays consistent with what the
server has processed.

### 9. Debug logging gating

All informational `debugPrint` calls gated behind `config.debugLogging`.
Error-level logs are always printed.

### 10. Subscription error handling

Added error-field parsing for subscription transition messages. The Convex
protocol may send `errorMessage`, `error_message`, `errorData`, or `error` keys
when a subscribed query fails. Previously these were silently ignored (the
update callback was never called). Now errors are forwarded to
`subscription.onError()`.

Also added a diagnostic log when a transition message contains neither `value`
nor an error field.

### 11. `setAuthWithRefresh` — initialToken parameter and auto-refresh

Added `initialToken` optional parameter to `setAuthWithRefresh` across the
interface, native client, and web client. When provided, the web client uses the
token directly for the initial `Authenticate` message instead of calling
`tokenFetcher()`, which would consume the single-use refresh token and cause
"Invalid refresh token" errors.

Also wired up automatic token refresh on the web client: when the server sends
an `AuthError` (emitted as `false` on `_authStateController`), the web client
calls `tokenFetcher()` to obtain a new JWT and re-authenticates. The
subscription is cancelled when the auth handle is disposed.

The native client accepts the parameter for interface compliance but ignores it
— the Rust SDK manages the initial fetch and refresh lifecycle internally.
