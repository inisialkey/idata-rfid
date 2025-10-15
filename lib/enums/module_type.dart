enum UhfModuleType {
  UM_MODULE('UM_MODULE'),
  SLR_MODULE('SLR_MODULE'),
  GX_MODULE('GX_MODULE'),
  RM_MODULE('RM_MODULE'),
  YRM_MODULE('YRM_MODULE');

  final String value;
  const UhfModuleType(this.value);

  /// Get value for platform channel
  String get platformValue => value;
}
