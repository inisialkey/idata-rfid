enum InventoryMode {
  // SLR Module modes
  s0Async(0, 'S0 Async'),
  s1Async(1, 'S1 Async'),
  smart(2, 'Smart'),
  fast(3, 'Fast'),
  raw(4, 'Raw Inventory'),
  ct(5, 'CT'),
  e7AutoRe(7, 'E7 Auto Re'),
  e7AutoReV2(8, 'E7 Auto Re V2');

  final int value;
  final String description;
  const InventoryMode(this.value, this.description);
}
