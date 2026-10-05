/// Normalized exception thrown by [ApiClient] for any failed HTTP call.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;

  /// Laravel-style per-field validation errors, if the response was a 422
  /// validation failure: `{"errors": {"email": ["The email has already
  /// been taken."]}}`. Null when the server didn't return this shape.
  final Map<String, List<String>>? errors;

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}
