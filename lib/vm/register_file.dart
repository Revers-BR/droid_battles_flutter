import 'dart:typed_data';

/// Porte de como `RobCpu`/`CPU` guardam seus registradores em
/// src/cpu.h (droidbattles original).
///
/// No C++ original, `registers` é um `uint16_t[256]` e `bit8reg`,
/// `iregisters`, `ibit8reg` são o MESMO bloco de memória reinterpretado
/// como `uint8_t*`, `int16_t*`, `int8_t*` respectivamente:
///
/// ```cpp
/// registers = new uint16_t[256];
/// bit8reg = (uint8_t *)&registers[0];
/// iregisters = (int16_t *)&registers[0];
/// ibit8reg = (int8_t *)&registers[0];
/// ```
///
/// Isso importa porque o assembly original tem instruções "8 bit" que
/// operam em `bit8reg[n]`, onde `n` é um índice de BYTE dentro do
/// array de 256 words (512 bytes) — não um índice de registrador
/// separado. `RegisterFile` replica esse aliasing byte-a-byte usando
/// `ByteData` sobre um buffer fixo, com endianness explicitamente
/// little-endian (era o comportamento de fato em x86, plataforma do
/// jogo original).
class RegisterFile {
  static const int registerCount = 256;

  final ByteData _data = ByteData(registerCount * 2);

  /// Equivalente a `registers[index]` (word de 16 bits, sem sinal).
  int getWord(int index) => _data.getUint16(index * 2, Endian.little);

  void setWord(int index, int value) {
    _data.setUint16(index * 2, value & 0xFFFF, Endian.little);
  }

  /// Equivalente a `iregisters[index]` (word de 16 bits, com sinal).
  int getIWord(int index) => _data.getInt16(index * 2, Endian.little);

  void setIWord(int index, int value) {
    _data.setInt16(index * 2, value.toSigned(16), Endian.little);
  }

  /// Equivalente a `bit8reg[byteIndex]` — endereçamento por BYTE dentro
  /// do mesmo buffer dos registradores de 16 bits.
  int getByte(int byteIndex) => _data.getUint8(byteIndex);

  void setByte(int byteIndex, int value) {
    _data.setUint8(byteIndex, value & 0xFF);
  }

  /// Equivalente a `ibit8reg[byteIndex]`.
  int getIByte(int byteIndex) => _data.getInt8(byteIndex);

  void setIByte(int byteIndex, int value) {
    _data.setInt8(byteIndex, value.toSigned(8));
  }

  /// Açúcar sintático para `registers[index]++` / `registers[index]--`.
  void incWord(int index, [int by = 1]) => setWord(index, getWord(index) + by);
  void decWord(int index, [int by = 1]) => setWord(index, getWord(index) - by);
  void incByte(int byteIndex, [int by = 1]) =>
      setByte(byteIndex, getByte(byteIndex) + by);
  void decByte(int byteIndex, [int by = 1]) =>
      setByte(byteIndex, getByte(byteIndex) - by);
}
