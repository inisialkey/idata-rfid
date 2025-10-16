class UhfResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final String? errorCode;

  UhfResponse({required this.success, this.data, this.error, this.errorCode});

  /// Create success response
  factory UhfResponse.success(T data) => UhfResponse(success: true, data: data);

  /// Create error response
  factory UhfResponse.error(String code, String message) =>
      UhfResponse(success: false, error: message, errorCode: code);
}
