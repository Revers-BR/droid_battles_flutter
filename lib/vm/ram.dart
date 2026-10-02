import 'dart:typed_data';

// Porte de src/ram.h e src/ram.cpp (droidbattles original).
//
// Diferenças da fonte C++ mantidas de propósito:
// - getbyte(0) no original cai no "return 0xFF" (o teste é `adress > 0`,
//   não `>= 0`) — reproduzido aqui para manter o comportamento do bot
//   original (o endereço 0 nunca é lido como dado válido por getByte).
// - getWord/getIWord fazem little-endian: byte baixo primeiro.
class Ram {
  final Uint8List _mem;
  int _numOwners = 1;

  /// Tamanhos de RAM disponíveis na criação de um bot (em bytes).
  static const List<int> sizeOptions = [
    1024,
    2048,
    4096,
    8192,
    16384,
    24576,
    32768,
    49152,
    65536,
  ];

  /// RAM vazia mínima (equivalente ao construtor `Ram()` do original).
  Ram.empty()
      : _mem = Uint8List(1),
        _numOwners = 1;

  /// Cria a RAM já carregada com o conteúdo do bot.
  ///
  /// [buf] é o arquivo `.bot` completo; os primeiros 256 bytes são
  /// cabeçalho e são pulados, igual ao original (`buf[x + 256]`).
  factory Ram.fromBotFile(int amount, Uint8List buf) {
    final mem = Uint8List(amount);
    for (var x = 0; x < amount; x++) {
      mem[x] = buf[x + 256];
    }
    return Ram._(mem);
  }

  Ram._(this._mem);

  int get ramAmount => _mem.length;

  /// Byte sem sinal. Note: endereço 0 sempre retorna 0xFF (fiel ao original).
  int getByte(int address) {
    if (address > 0 && address < _mem.length) {
      return _mem[address];
    }
    return 0xFF;
  }

  /// Byte com sinal.
  int getIByte(int address) {
    if (address < _mem.length) {
      return _mem[address].toSigned(8);
    }
    return 0xFF;
  }

  /// Word (16 bits) sem sinal, little-endian.
  int getWord(int address) {
    if (address < _mem.length - 1) {
      return _mem[address] + _mem[address + 1] * 256;
    }
    return 0xFFFF;
  }

  /// Word (16 bits) com sinal, little-endian.
  int getIWord(int address) {
    if (address < _mem.length - 1) {
      final unsigned = _mem[address] + _mem[address + 1] * 256;
      return unsigned.toSigned(16);
    }
    return 0xFFFF;
  }

  void setByte(int address, int value) {
    if (address < _mem.length) {
      _mem[address] = value & 0xFF;
    }
  }

  void setIByte(int address, int value) {
    if (address < _mem.length) {
      _mem[address] = value.toUnsigned(8);
    }
  }

  void setWord(int address, int value) {
    if (address < _mem.length - 1) {
      _mem[address] = value % 256;
      _mem[address + 1] = value ~/ 256;
    }
  }

  void setIWord(int address, int value) {
    if (address < _mem.length - 1) {
      final unsigned = value.toUnsigned(16);
      _mem[address] = unsigned % 256;
      _mem[address + 1] = unsigned ~/ 256;
    }
  }

  int returnSize() => _mem.length;

  int get owners => _numOwners;
  void addOwner() => _numOwners++;
  void removeOwner() => _numOwners--;
}
