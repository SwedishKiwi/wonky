import 'dart:async';

import 'package:wonky_client/wonky_client.dart';

/// Thrown when the server cannot be reached; repositories fall back to the
/// local cache / pending queue.
class OfflineException implements Exception {
  const OfflineException([this.cause]);
  final Object? cause;
  @override
  String toString() => 'OfflineException($cause)';
}

/// Thin wrapper over the generated client used by the server repositories.
///
/// Calls go through `callServerEndpoint` with the spec'd endpoint/method
/// names, so the shell works against the real endpoints as soon as the server
/// exposes them (independent of client regeneration order).
class Api {
  Api(this.client);

  final Client client;

  /// Calls `endpoint.method(args)`.
  Future<T> call<T>(
    String endpoint,
    String method, [
    Map<String, dynamic> args = const {},
    bool authenticated = true,
  ]) async {
    try {
      return await client.callServerEndpoint<T>(
        endpoint,
        method,
        args,
        authenticated: authenticated,
      );
    } on ServerpodClientNetworkException catch (e) {
      throw OfflineException(e);
    } on TimeoutException catch (e) {
      throw OfflineException(e);
    }
  }

  /// Opens a streaming method (`watch`, `join`, …).
  Stream<T> stream<T>(
    String endpoint,
    String method, [
    Map<String, dynamic> args = const {},
    Map<String, Stream<dynamic>> streams = const {},
  ]) =>
      client.callStreamingServerEndpoint<Stream<T>, T>(
            endpoint,
            method,
            args,
            streams,
          )
          as Stream<T>;
}

/// Whether [e] means "the server is unreachable".
bool isOfflineError(Object e) =>
    e is OfflineException ||
    e is ServerpodClientNetworkException ||
    e is TimeoutException;

/// A user-facing message for an error thrown by a repository.
String errorMessage(Object e) {
  if (e is WonkyException) return e.message;
  if (isOfflineError(e)) return 'You are offline.';
  if (e is ServerpodClientException) return e.message;
  return '$e';
}
