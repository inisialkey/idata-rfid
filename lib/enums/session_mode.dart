enum SessionMode {
  s0(0, 'S0'),
  s1(1, 'S1'),
  s2(2, 'S2'),
  s3(3, 'S3');

  final int value;
  final String description;
  const SessionMode(this.value, this.description);
}
