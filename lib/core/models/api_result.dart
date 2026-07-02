/// Generic success/failure wrapper for service and API calls.
class ApiResult<T> {
  const ApiResult({
    required this.isSuccess,
    this.data,
    this.message,
    this.statusCode,
  });

  final bool isSuccess;
  final T? data;
  final String? message;
  final int? statusCode;

  factory ApiResult.ok(T data, {int? statusCode}) => ApiResult(
        isSuccess: true,
        data: data,
        statusCode: statusCode,
      );

  factory ApiResult.fail(String message, {int? statusCode}) => ApiResult(
        isSuccess: false,
        message: message,
        statusCode: statusCode,
      );
}
