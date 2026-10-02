// Porte de src/matchresult.h (droidbattles original) -- resultado de
// um confronto dentro de um torneio (usado por startcup/starttournament).
class MatchResult {
  MatchResult({
    this.mainBot = 0,
    this.secBot = 0,
    this.mainBotWins = 0,
    this.secBotWins = 0,
  });

  int mainBot;
  int secBot;
  int mainBotWins;
  int secBotWins;
}
