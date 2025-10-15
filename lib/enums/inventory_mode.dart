enum InventoryMode {
  // SLR Module modes
  S0_ASYNC(0, 'S0 Async'),
  S1_ASYNC(1, 'S1 Async'),
  SMART(2, 'Smart'),
  FAST(3, 'Fast'),
  RAW(4, 'Raw Inventory'),
  CT(5, 'CT'),
  E7_AUTO_RE(7, 'E7 Auto Re'),
  E7_AUTO_RE_V2(8, 'E7 Auto Re V2');

  final int value;
  final String description;
  const InventoryMode(this.value, this.description);
}
