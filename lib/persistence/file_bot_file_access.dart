import 'dart:io';

import 'bot_file_access.dart';

// Implementacao de verdade de [BotFileAccess] usando `dart:io`. Sem
// equivalente no C++ (a implementacao real la e so `QFile` direto,
// sem abstracao) -- aqui e o "plugue" concreto que a UI mobile usa,
// escrevendo dentro de um diretorio raiz fixo (normalmente a pasta de
// documentos do app, de `path_provider`).
//
// [path] recebido pela interface (`ourbot.myfile`, algo como
// "meubot.dat") e resolvido relativo a [rootDir] -- nunca deixamos um
// bot ler/escrever fora dessa pasta.
class FileBotFileAccess implements BotFileAccess {
  FileBotFileAccess(this.rootDir);

  final Directory rootDir;

  File _resolve(String path) {
    // So o nome do arquivo importa -- ignora qualquer diretorio que
    // porventura venha embutido em `path`, por seguranca.
    final safeName = path.split(Platform.pathSeparator).last.split('/').last;
    return File('${rootDir.path}${Platform.pathSeparator}$safeName');
  }

  @override
  int readAt(String path, int start, int length, List<int> destination, int destOffset) {
    final file = _resolve(path);
    if (!file.existsSync()) return -1;
    RandomAccessFile? raf;
    try {
      raf = file.openSync(mode: FileMode.read);
      raf.setPositionSync(start);
      final bytes = raf.readSync(length);
      for (var i = 0; i < bytes.length; i++) {
        destination[destOffset + i] = bytes[i];
      }
      return bytes.length;
    } catch (_) {
      return -1;
    } finally {
      raf?.closeSync();
    }
  }

  @override
  int writeAt(String path, int start, List<int> source, int sourceOffset, int length) {
    final file = _resolve(path);
    RandomAccessFile? raf;
    try {
      // Fiel ao original: abrir "WriteOnly" trunca o arquivo antes de
      // escrever (ver o aviso em bot_file_access.dart).
      raf = file.openSync(mode: FileMode.write);
      raf.setPositionSync(start);
      raf.writeFromSync(source, sourceOffset, sourceOffset + length);
      return length;
    } catch (_) {
      return -1;
    } finally {
      raf?.closeSync();
    }
  }
}
