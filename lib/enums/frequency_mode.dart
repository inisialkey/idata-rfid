enum FrequencyMode {
  CHINA_840_845(0, 'China 840-845MHz'),
  CHINA_920_925(1, 'China 920-925MHz'),
  EUROPE_865_868(2, 'Europe 865-868MHz'),
  USA_902_928(3, 'USA 902-928MHz'),
  OPEN(4, 'Open'),
  CUSTOM(5, 'Custom');

  final int value;
  final String description;
  const FrequencyMode(this.value, this.description);
}
