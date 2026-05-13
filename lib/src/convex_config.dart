import 'convex_logger.dart';

/// Configuration for ConvexClient initialization.
///
/// This class holds all configuration options for initializing
/// the Convex client singleton.
///
/// Example usage:
/// ```dart
/// await ConvexClient.initialize(
///   ConvexConfig(
///     deploymentUrl: "https://your-app.convex.cloud",
///     clientId: "flutter-app",
///     operationTimeout: Duration(seconds: 30),
///     healthCheckQuery: "system:ping",
///   ),
/// );
/// ```
class ConvexConfig {
  /// The URL of your Convex deployment.
  ///
  /// Example: "https://my-app.convex.cloud"
  final String deploymentUrl;

  /// Optional unique identifier for this client instance.
  ///
  /// If not provided, defaults to 'flutter-client'.
  final String? clientId;

  /// Timeout duration for all query, mutation, and action operations.
  ///
  /// Operations that take longer than this duration will throw
  /// a TimeoutException. Defaults to 30 seconds.
  final Duration operationTimeout;

  /// Optional query name to use for manual connection health checks.
  ///
  /// This should be the name of a lightweight query in your Convex backend
  /// that can be used to verify the connection is working.
  ///
  /// Example: "system:ping" or any query that returns quickly.
  ///
  /// If null, calling `ConvexClient.instance.checkConnection()` will throw
  /// a StateError. You can still check connection by attempting regular
  /// queries and catching TimeoutException.
  final String? healthCheckQuery;

  /// Callback invoked for every diagnostic log emitted by the Dart side
  /// of the client (native and web).
  ///
  /// Receives `(level, source, message)`. Implementations should filter
  /// by level and route to whatever logging framework the host app uses
  /// (e.g. `package:logging`, Sentry, stdout).
  ///
  /// Defaults to [defaultConvexLogger], which emits `warn` and `error`
  /// via `debugPrint`. Use [silentConvexLogger] to drop everything, or
  /// pass a custom callback to integrate with your logger.
  ///
  /// Does **not** receive Rust-side logs (those go to logcat on Android
  /// via `android_logger`; control their volume with [verboseNativeLogs]).
  final ConvexLogger logger;

  /// Whether the native Rust client emits debug-level logs to logcat
  /// (Android). When `false` (default), only warnings and errors are
  /// surfaced. When `true`, all Convex SDK tracing events (reconnect,
  /// backoff, protocol chatter) are emitted at debug level.
  ///
  /// Independent of [logger]: Rust-side logs go through `android_logger`,
  /// not through the [ConvexLogger] callback.
  ///
  /// No effect on the web transport (no Rust runtime there).
  final bool verboseNativeLogs;

  /// Whether to coerce whole-number doubles (e.g. `42.0`) to ints (`42`)
  /// in query/mutation/action/subscribe results on the native FFI path.
  ///
  /// The native (Rust) transport serialises all Convex `Float64` values
  /// with a decimal point, while the web transport emits ints for whole
  /// numbers. Without normalisation, `as int` casts in consumer DTOs
  /// throw on mobile but succeed on web.
  ///
  /// Defaults to `true` (cross-transport symmetry). Set to `false` if you
  /// need to preserve the distinction between `42` and `42.0` — useful
  /// when the JSON payload encodes that distinction semantically.
  ///
  /// No effect on the web transport.
  final bool convertWholeNumberDoublesToInts;

  /// Creates a new ConvexConfig with the specified options.
  const ConvexConfig({
    required this.deploymentUrl,
    this.clientId,
    this.operationTimeout = const Duration(seconds: 30),
    this.healthCheckQuery,
    this.logger = defaultConvexLogger,
    this.verboseNativeLogs = false,
    this.convertWholeNumberDoublesToInts = true,
  });
}
