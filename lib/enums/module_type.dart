enum UhfModuleType {
  umModule('UM_MODULE'),
  slrModule('SLR_MODULE'),
  gxModule('GX_MODULE'),
  rmModule('RM_MODULE'),
  yrmModule('YRM_MODULE');

  final String value;
  const UhfModuleType(this.value);

  /// Get value for platform channel
  String get platformValue => value;
}
