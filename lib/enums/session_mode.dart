enum SessionMode {
  S0(0, 'S0'),
  S1(1, 'S1'),
  S2(2, 'S2'),
  S3(3, 'S3');

  final int value;
  final String description;
  const SessionMode(this.value, this.description);
}
