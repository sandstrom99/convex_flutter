import 'package:flutter/foundation.dart';

/// Severity of a log event emitted by the Convex client.
enum ConvexLogLevel { debug, info, warn, error }

/// Callback invoked for every log event the Convex client wants to surface.
///
/// - [level] is the severity.
/// - [source] is a short tag identifying the subsystem (e.g. `"native"`,
///   `"web"`, `"auth"`, `"ws"`).
/// - [message] is the human-readable log line.
///
/// Implementations should be cheap and non-throwing; the client does not
/// guard against logger exceptions.
typedef ConvexLogger =
    void Function(ConvexLogLevel level, String source, String message);

/// Default logger — emits `warn` and `error` to [debugPrint], drops
/// `debug` and `info`. Suitable when the consumer hasn't wired up its own
/// logging framework.
void defaultConvexLogger(ConvexLogLevel level, String source, String message) {
  if (level.index < ConvexLogLevel.warn.index) return;
  debugPrint('[convex_flutter/$source/${level.name}] $message');
}

/// Silent logger — drops everything. Use when integrating with a logging
/// framework that handles its own output suppression, or in tests.
void silentConvexLogger(ConvexLogLevel _, String __, String ___) {}
