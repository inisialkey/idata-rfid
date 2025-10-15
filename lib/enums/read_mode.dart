enum ReadMode {
  EPC_ONLY(0, 'EPC Only'),
  EPC_AND_TID(1, 'EPC and TID'),
  EPC_AND_USER(2, 'EPC and User'),
  EPC_TID_USER(3, 'EPC, TID and User'),
  EPC_TID_RESERVED(4, 'EPC, TID and Reserved'),
  EPC_RESERVED(5, 'EPC and Reserved');

  final int value;
  final String description;
  const ReadMode(this.value, this.description);
}
