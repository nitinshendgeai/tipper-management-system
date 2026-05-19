import 'package:dio/dio.dart';

/// Extracts a human-readable error message from any exception.
///
/// Priority:
///   1. Server JSON `detail` field from a DioException response body
///   2. HTTP status-based fallback message
///   3. Network / socket error
///   4. Generic fallback
///
/// Phase 6 (FE-006): replaces scattered string-match error parsing across
/// all screens with a single, consistent extractor.
class ApiError {
  ApiError._();

  static String extract(Object e, {String fallback = 'Something went wrong. Please try again.'}) {
    if (e is DioException) {
      // 1. Try to read the server's "detail" field
      final data = e.response?.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
      }

      // 2. HTTP status-code fallbacks
      final status = e.response?.statusCode;
      if (status == 401) return 'Session expired — please sign in again.';
      if (status == 403) return 'You do not have permission to perform this action.';
      if (status == 404) return 'The requested resource was not found.';
      if (status == 409) return 'Conflict — another operation is blocking this action.';
      if (status == 422) return 'Invalid input — please check the values you entered.';
      if (status != null && status >= 500) {
        return 'Server error (${status}) — please try again later.';
      }

      // 3. Network / connectivity errors
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return 'Request timed out — check your connection and try again.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Cannot reach the server — check your network connection.';
      }
    }

    // 4. Generic fallback
    return fallback;
  }
}
