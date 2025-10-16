enum ReadMode {
  epcOnly(0, 'EPC Only'),
  epcAndTid(1, 'EPC and TID'),
  epcAndUser(2, 'EPC and User'),
  epcTidUser(3, 'EPC, TID and User'),
  epcTidReserved(4, 'EPC, TID and Reserved'),
  epcReserved(5, 'EPC and Reserved');

  final int value;
  final String description;
  const ReadMode(this.value, this.description);
}
