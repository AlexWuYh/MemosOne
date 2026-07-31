sealed class AppFailure implements Exception {
  const AppFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.cause, this.statusCode});

  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
}

class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {super.cause});
}

class StorageFailure extends AppFailure {
  const StorageFailure(super.message, {super.cause});
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {super.cause});
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message, {super.cause});
}

class SyncFailure extends AppFailure {
  const SyncFailure(super.message, {super.cause});
}
