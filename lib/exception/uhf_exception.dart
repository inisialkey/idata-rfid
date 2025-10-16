class UhfException implements Exception {
  final String code;
  final String message;
  final dynamic originalError;

  UhfException(this.code, this.message, [this.originalError]);

  @override
  String toString() => 'UhfException($code): $message';
}

/// Thrown when UHF device is not initialized
class UhfNotInitializedException extends UhfException {
  UhfNotInitializedException()
    : super('NOT_INITIALIZED', 'UHF device not initialized');
}

/// Thrown when power operation fails
class UhfPowerException extends UhfException {
  UhfPowerException(String message) : super('POWER_ERROR', message);
}

/// Thrown when inventory operation fails
class UhfInventoryException extends UhfException {
  UhfInventoryException(String message) : super('INVENTORY_ERROR', message);
}

/// Thrown when configuration operation fails
class UhfConfigException extends UhfException {
  UhfConfigException(String message) : super('CONFIG_ERROR', message);
}

/// Thrown when state is invalid for operation
class UhfStateException extends UhfException {
  UhfStateException(String message) : super('STATE_ERROR', message);
}
