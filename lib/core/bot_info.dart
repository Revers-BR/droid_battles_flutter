import 'robots.dart';
import 'screen_object.dart';

// Porte da LOGICA de src/botinfo.h e src/botinfo.cpp (droidbattles
// original) -- o original e um painel Qt inteiro (QLabel/QProgressBar/
// QCheckBox mostrando nome, armadura, calor, combustivel e mensagens
// do bot); so a conta de `score()` nao e UI, entao e o unico pedaco
// portado aqui. O resto (o painel em si) e responsabilidade da tela
// mobile, usando os callbacks `onArmorChanged`/`onFuelChanged`/
// `onMessageChanged` que `ScreenObject` ja expoe.
class BotInfo {
  BotInfo(String botName, ScreenObject screenObject) {
    displayName = botName;
    final bot = screenObject is Robots ? screenObject : null;
    if (bot == null || botName.isEmpty) {
      _valid = false;
      return;
    }

    _cost = bot.cost();
    // Era `armorlevel.setMaximum(bot->armorval)` -- o maximo fica
    // fixo no valor de CRIACAO do bot, so o "value" atual muda depois
    // via `onArmorChanged`. Mesma logica pro combustivel.
    maxArmor = bot.armorval;
    currentArmor = bot.armorval;
    maxFuel = bot.fuelval;
    currentFuel = 0; // so atualiza quando onFuelChanged dispara, como no original

    screenObject.onArmorChanged = (x) {
      currentArmor = x;
      if (x <= 0) _valid = false; // era desabilitar os widgets
    };
    screenObject.onFuelChanged = (fuel, heat) {
      currentFuel = fuel;
      currentHeat = heat;
    };
    screenObject.onMessageChanged = (msg) {
      lastMessage = msg;
    };
  }

  bool _valid = true;
  bool get isValid => _valid;

  late String displayName;
  int _cost = 0;
  int maxArmor = 0;
  int currentArmor = 0;
  int maxFuel = 0;
  int currentFuel = 0;
  int currentHeat = 0;
  String lastMessage = '';

  /// Era `BotInfo::score()` -- usado por `storeScores()` (ainda nao
  /// portado, junto com a persistencia de arquivos).
  int score() {
    var ret = -_cost;
    if (maxArmor != 0) {
      ret += 1000 * currentArmor ~/ maxArmor;
    }
    if (maxFuel != 0) {
      ret += 1000 * currentFuel ~/ maxFuel;
    }
    return ret;
  }
}
