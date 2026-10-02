import 'dart:typed_data';

// Porte do FORMATO do arquivo .bot do droidbattles original (ver
// `CreateBot::assemble()` em createbot.cpp e `Robots::Robots` em
// robots.cpp). Isto NAO le/escreve do disco -- so converte entre
// bytes crus (o que voce le de um arquivo/asset) e o array `mem` que
// `Robots(..., botFileBytes: ...)` espera. Ler/escrever o arquivo em
// si fica por conta de quem chama, mesma divisao usada no resto do
// projeto (ver cpu.dart, conf_struct.dart).
//
// Layout de um `.bot` no disco:
//   [4 bytes, uint32 big-endian] tamanho de `mem` que vem a seguir
//     -- isso e o framing do `QDataStream::writeBytes` do Qt, nao e
//        escolha nossa; sem ele o arquivo nao bate com um .bot criado
//        pelo droidbattles original (nem seria lido por ele).
//   [mem[0]]              'B' (66) -- byte magico, so decorativo,
//                          `Robots.load` nunca confere ele.
//   [mem[1]]               indice do tamanho de RAM (0-8, ver
//                          `Ram.sizeOptions`)
//   [mem[2 + i*6 .. 7+i*6] para i em 0..31] tabela de 32 devices:
//     +0 tipo do device (0 = nenhum, 1 = CPU, ... 20 = RocketLauncher)
//     +1 nivel escolhido (0-4)
//     +2 arg1 (usado por Plasma/Scanner/Turret/RadarMissileLauncher/
//        RocketLauncher) OU, se for CPU, os 4 bytes +2..+5 sao
//        bootMemLow/bootMemHigh/stackMemLow/stackMemHigh (escritos
//        pelas diretivas `%CPUboot`/`%CPUstack` do assembler)
//     +3..+5 nao usados pelos devices que nao sao CPU (ficam 0)
//   [mem[256 .. 256+RAMAMOUNT-1]] o programa/dados do bot (RAM real)
class BotFile {
  const BotFile._();

  static const int headerSize = 256;
  static const int magicByte = 0x42; // 'B'

  /// Recebe os bytes CRUS do arquivo `.bot` (com o prefixo de tamanho
  /// do QDataStream) e devolve so o `mem` (header de 256 bytes + RAM)
  /// -- o formato que `Robots(..., botFileBytes: ...)` espera.
  ///
  /// Lanca [FormatException] se o arquivo for curto demais ou o
  /// tamanho declarado no prefixo nao bater com o resto dos bytes.
  static Uint8List stripFraming(List<int> raw) {
    if (raw.length < 4) {
      throw const FormatException('Arquivo .bot menor que o cabeçalho de tamanho (4 bytes)');
    }
    final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
    final declaredLength = ByteData.sublistView(bytes, 0, 4).getUint32(0, Endian.big);
    if (bytes.length - 4 < declaredLength) {
      throw FormatException(
        'Arquivo .bot truncado: cabeçalho diz $declaredLength bytes, mas só há ${bytes.length - 4}',
      );
    }
    return Uint8List.sublistView(bytes, 4, 4 + declaredLength);
  }

  /// Inverso de [stripFraming]: adiciona o prefixo de tamanho do
  /// QDataStream em cima do `mem` pronto (256 + tamanho da RAM
  /// bytes), pra virar um arquivo `.bot` de verdade.
  static Uint8List addFraming(List<int> mem) {
    final body = mem is Uint8List ? mem : Uint8List.fromList(mem);
    final out = Uint8List(4 + body.length);
    ByteData.sublistView(out, 0, 4).setUint32(0, body.length, Endian.big);
    out.setRange(4, out.length, body);
    return out;
  }

  /// Le o indice de tamanho de RAM (mem[1]) sem montar um `Robots`
  /// inteiro -- util pra telas de listagem/detalhe de bot.
  static int ramSizeIndex(List<int> mem) => mem.length > 1 ? mem[1] : 0;
}
