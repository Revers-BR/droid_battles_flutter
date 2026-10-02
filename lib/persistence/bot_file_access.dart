// Porte da interface de arquivo que `CPU::readfile`/`CPU::writefile`
// usam (era `QFile f(ourbot->myfile)` no C++ original). Um bot em
// execucao pode ler/escrever bytes de um arquivo de dados PROPRIO
// durante a batalha (instrucoes 0x93/0x94 da VM) -- NAO e o .bot
// (script) em si: `Robots::myfile` e montado como o nome do bot com
// os 3 ultimos caracteres trocados por "dat" (ex.: "meubot.bot" vira
// "meubot.dat"), entao cada bot tem seu proprio arquivo de dados
// persistente entre rodadas, separado do script. Isso e acesso a
// disco de verdade, entao fica igual ao resto do projeto: uma
// interface pluggable que a camada de plataforma (mobile) implementa
// com o pacote de arquivos que preferir (`dart:io`, `path_provider`,
// etc. -- ver `lib/persistence/file_bot_file_access.dart` pra uma
// implementacao de verdade); sem uma instancia configurada, as
// leituras/escritas falham (-1), igual a um `QFile::open` que falha
// no original.
abstract class BotFileAccess {
  /// Le ate `length` bytes de `path` a partir do byte `start`.
  /// Retorna quantos bytes leu de fato (-1 se nao conseguiu abrir).
  int readAt(String path, int start, int length, List<int> destination, int destOffset);

  /// Escreve `length` bytes em `path` a partir do byte `start`.
  ///
  /// ATENCAO -- fiel ao original: `QFile::open(WriteOnly)` sem
  /// `Append` TRUNCA o arquivo antes de escrever (mesmo comportamento
  /// de `open(path, 'w')` na maioria das linguagens). Ou seja, um bot
  /// que chama a instrucao WRITEFILE apaga o proprio arquivo .bot e
  /// escreve so os `length` bytes a partir de `start` -- e um
  /// comportamento estranho/perigoso do jogo original, nao um bug do
  /// porte; documentado aqui pra quem for implementar esta interface
  /// nao se assustar.
  int writeAt(String path, int start, List<int> source, int sourceOffset, int length);
}
