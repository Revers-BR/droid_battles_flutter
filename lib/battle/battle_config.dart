// Porte de src/battleconfig.h (droidbattles original).
class BattleConfig {
  BattleConfig({
    List<String>? names,
    this.xSize = 32768,
    this.ySize = 32768,
    this.isTeams = false,
    this.isTournament = false,
    this.mode = FightMode.normal,
    this.maxRounds = 6000,
    this.maxPoints = 10,
    this.numFights = 1,
    List<int>? teams,
    this.fastMode = false,
    this.debugMode = false,
    this.randomSeed,
  })  : names = _pad(names, 8, ''),
        teams = _pad(teams, 8, 0);

  /// Era `std::array<QString, 8> names` / `std::array<int, 8> teams`
  /// no C++ original -- SEMPRE 8 posicoes. Aqui `names`/`teams` sao
  /// `List` (nao um array de tamanho fixo), entao normalizamos pra 8
  /// elementos aqui, na criacao -- corta se vier maior, completa com
  /// [fill] se vier menor. Sem isso, passar (por exemplo) so 3 nomes
  /// pra uma partida de 3 bots faz o resto da arena (que sempre
  /// itera ate `maxBots`=8) estourar índice.
  static List<T> _pad<T>(List<T>? source, int length, T fill) {
    return List<T>.generate(length, (i) => source != null && i < source.length ? source[i] : fill);
  }

  /// Nomes dos ate 8 bots (slot vazio = "" = nenhum bot ali).
  final List<String> names;

  int xSize;
  int ySize;
  bool isTeams;
  bool isTournament;

  /// Era o enum `FightMode` (Normal/Survival/Deathmatch).
  int mode;

  int maxRounds;
  int maxPoints;
  int numFights;

  /// Time de cada slot (0-3), so usado quando `isTeams` e true.
  final List<int> teams;

  bool fastMode;
  bool debugMode;

  /// Era `std::random_device::result_type random_seed` -- se null,
  /// a arena usa uma seed aleatoria de verdade.
  int? randomSeed;
}

/// Era o enum `BattleConfig::FightMode`.
class FightMode {
  static const int normal = 0;
  static const int survival = 1;
  static const int deathmatch = 2;
}
