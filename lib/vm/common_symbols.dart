import 'dart:math' as math;

// Porte de src/commonsymbols.h (droidbattles original).
// Mantido 1:1 — sao constantes usadas pela CPU, pelos devices e pela
// arena. Nao altere os valores sem checar o impacto em bots/replays
// existentes: fazem parte do "contrato" binario do jogo original.

// --- indices dos registradores da CPU ---
const int eip = 5;
const int ax = 1;
const int bx = 2;
const int cx = 3;
const int dx = 4;
const int sp = 9;
const int bp = 8;
const int al = 2;
const int ah = 3;
const int bl = 4;
const int bh = 5;
const int cl = 6;
const int ch = 7;
const int dl = 8;
const int dh = 9;
const int di = 6;
const int si = 7;
const int flagsReg = 0; // "flags" no original; renomeado p/ nao colidir

const int portsPerDev = 4;

// --- indices das interrupcoes ---
const int hitInterrupt = 0;
const int timeInterrupt = 1;
const int msgInterrupt = 2;
const int armLevelInt = 3;
const int fuelLevelInt = 4;

// --- constantes de operacao do registrador de flags ---
const int setEqualFlag = 0x8000;
const int setAboveFlag = 0x2000;
const int setBelowFlag = 0x4000;
const int setInterruptFlag = 0x0400;

const int aboveFlag = 0x2000;
const int belowFlag = 0x4000;
const int equalFlag = 0x8000;

const int clearEqualFlags = 0x9FFF;
const int clearAboveFlags = 0x3FFF;
const int clearBelowFlags = 0x5FFF;
const int setUnequalFlag = 0x7FFF;
const int clearInterruptFlag = 0xFBFF;

// --- codigos de tipo de device ---
const int armorType = 99;
const int cpuType = 9;
const int cpuWithInt = 5;
const int scanWarnType = 11;
const int collEnabled = 256;

const int maxObjects = 255;
const int maxBots = 8;
const int maxTeams = 4;

const int firstRun = 0;
const int notFirstRound = 1;

const int minStartDistance = 2000;

final double toRadians = math.pi / 512;
final double toBotGrades = 512 / math.pi;
const int debugBot = 7;

const int numDev = 20;

// --- diversos ---
const int maxBeamLength = 8000;
const int minBeamLength = 1100;
const int beamDamage = 7;

const int objHitDestroyed = 1;
const int objHitNotDestroyed = 0;
const int destroySelf = -1;
const int seenByRadar = 1;
