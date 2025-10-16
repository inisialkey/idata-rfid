enum FrequencyMode {
  china_840_845(0, 'China 840-845MHz'),
  china_920_925(1, 'China 920-925MHz'),
  europe_865_868(2, 'Europe 865-868MHz'),
  usa_902_928(3, 'USA 902-928MHz'),
  open(4, 'Open'),
  custom(5, 'Custom');

  final int value;
  final String description;
  const FrequencyMode(this.value, this.description);
}
