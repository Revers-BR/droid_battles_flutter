// Porte da tabela de simbolos automaticos por device, gerada no
// inicio de `CreateBot::assemble()` (createbot.cpp, ~linhas 780-1320).
// Pra cada device escolhido no bot, o assembler original cria ate 8
// nomes simbolicos (`<Tipo><N>_<Sufixo>`, onde N e o indice desse
// device entre os do MESMO TIPO no bot, comecando em 0) apontando pro
// numero de porta (0-3) correspondente -- e assim que o assembly usa
// nomes tipo `Scanner0_Scan` em vez de portas cruas.
//
// Cada entrada e (slotOffset 0-7, sufixo). `nvalues` do simbolo =
// deviceIndex*4 + (slotOffset % 4) -- os slots 0-3 sao "getters", os
// slots 4-7 sao "setters" que reusam as mesmas 4 portas.
class DeviceSymbolEntry {
  const DeviceSymbolEntry(this.slot, this.prefix, this.suffix);
  final int slot;
  final String prefix;
  final String suffix;
}

/// Indexado por tipo de device (1-20, mesmo id de `Device.deviceName`
/// + 1). Tipo 13 (Repair) nao gera simbolos (lista vazia), fiel ao
/// original.
const Map<int, List<DeviceSymbolEntry>> kDeviceSymbolTable = {
  1: [ // CPU
    DeviceSymbolEntry(0, 'CPU', 'GetXSize'),
    DeviceSymbolEntry(1, 'CPU', 'GetYSize'),
    DeviceSymbolEntry(2, 'CPU', 'GetBattleType'),
    DeviceSymbolEntry(3, 'CPU', 'GetMyTeam'),
  ],
  2: [ // Engine
    DeviceSymbolEntry(0, 'Engine', 'GetThrust'),
    DeviceSymbolEntry(1, 'Engine', 'GetSpeed'),
    DeviceSymbolEntry(4, 'Engine', 'SetThrust'),
    DeviceSymbolEntry(5, 'Engine', 'SetReverseThrust'),
  ],
  3: [ // Steering
    DeviceSymbolEntry(0, 'Steering', 'GetDir'),
    DeviceSymbolEntry(1, 'Steering', 'GetWantedDir'),
    DeviceSymbolEntry(2, 'Steering', 'GetXPos'),
    DeviceSymbolEntry(3, 'Steering', 'GetYPos'),
    DeviceSymbolEntry(4, 'Steering', 'AdjustWantedDir'),
    DeviceSymbolEntry(5, 'Steering', 'SetDir'),
    DeviceSymbolEntry(6, 'Steering', 'AdjustCurrentDir'),
  ],
  4: [ // Plasma
    DeviceSymbolEntry(4, 'Plasmagun', 'Shoot'),
  ],
  5: [ // Armor
    DeviceSymbolEntry(0, 'Armor', 'GetArmor'),
    DeviceSymbolEntry(1, 'Armor', 'GetHeat'),
    DeviceSymbolEntry(4, 'Armor', 'SetCollIntEnabled'),
    DeviceSymbolEntry(5, 'Armor', 'SetArmorIntEnabled'),
    DeviceSymbolEntry(6, 'Armor', 'SetArmorIntLevel'),
    DeviceSymbolEntry(7, 'Armor', 'SetHeatIntLevel'),
  ],
  6: [ // Scanner
    DeviceSymbolEntry(0, 'Scanner', 'GetScanDistance'),
    DeviceSymbolEntry(1, 'Scanner', 'GetScanAccuracy'),
    DeviceSymbolEntry(2, 'Scanner', 'GetScanWidth'),
    DeviceSymbolEntry(3, 'Scanner', 'GetScanInfo'),
    DeviceSymbolEntry(4, 'Scanner', 'Scan'),
    DeviceSymbolEntry(5, 'Scanner', 'SetScanWidth'),
    DeviceSymbolEntry(6, 'Scanner', 'SelectReturn'),
    DeviceSymbolEntry(7, 'Scanner', 'SetSensitivity'),
  ],
  7: [ // Fuel
    DeviceSymbolEntry(0, 'Fuel', 'GetFuel'),
    DeviceSymbolEntry(4, 'Fuel', 'SetFuelIntEnabled'),
    DeviceSymbolEntry(5, 'Fuel', 'SetFuelIntLevel'),
  ],
  8: [ // Chaff
    DeviceSymbolEntry(0, 'Chaff', 'GetDebris'),
    DeviceSymbolEntry(4, 'Chaff', 'ReleaseDebris'),
  ],
  9: [ // Turret
    DeviceSymbolEntry(0, 'Turret', 'GetOffset'),
    DeviceSymbolEntry(1, 'Turret', 'GetWantedOffset'),
    DeviceSymbolEntry(4, 'Turret', 'SetOffset'),
    DeviceSymbolEntry(5, 'Turret', 'AdjustOffset'),
    DeviceSymbolEntry(6, 'Turret', 'AdjustCurrentOffset'),
  ],
  10: [ // ScanWarn (ScanDetect)
    DeviceSymbolEntry(0, 'ScanWarn', 'GetNumScans'),
    DeviceSymbolEntry(1, 'ScanWarn', 'GetScanDir'),
    DeviceSymbolEntry(2, 'ScanWarn', 'GetScanIntensity'),
    DeviceSymbolEntry(4, 'ScanWarn', 'ZeroCounter'),
  ],
  11: [ // Timer (TimeDev)
    DeviceSymbolEntry(0, 'Timer', 'GetTime'),
    DeviceSymbolEntry(1, 'Timer', 'GetIntTime'),
    DeviceSymbolEntry(2, 'Timer', 'GetIntEnabled'),
    DeviceSymbolEntry(4, 'Timer', 'SetTime'),
    DeviceSymbolEntry(5, 'Timer', 'SetIntTime'),
    DeviceSymbolEntry(6, 'Timer', 'SetIntEnabled'),
  ],
  12: [ // Shield
    DeviceSymbolEntry(0, 'Shield', 'GetShieldEnabled'),
    DeviceSymbolEntry(4, 'Shield', 'SetShieldEnabled'),
  ],
  13: [], // Repair -- sem simbolos automaticos, fiel ao original
  14: [ // Radio (Communication)
    DeviceSymbolEntry(0, 'Radio', 'GetNumMsgs'),
    DeviceSymbolEntry(1, 'Radio', 'GetMsg'),
    DeviceSymbolEntry(2, 'Radio', 'GetMyNum'),
    DeviceSymbolEntry(4, 'Radio', 'SetReceiver'),
    DeviceSymbolEntry(5, 'Radio', 'SendMsg'),
    DeviceSymbolEntry(6, 'Radio', 'SetMsgIntEnabled'),
  ],
  15: [ // Chiller
    DeviceSymbolEntry(4, 'Chiller', 'SetExtraCooling'),
  ],
  16: [ // Cloaker
    DeviceSymbolEntry(4, 'Cloak', 'EnableCloak'),
  ],
  17: [ // MineLayer
    DeviceSymbolEntry(0, 'Minelayer', 'GetMines'),
    DeviceSymbolEntry(4, 'Minelayer', 'LayMine'),
  ],
  18: [ // RadarMissileLauncher
    DeviceSymbolEntry(0, 'Missile', 'GetLoadTime'),
    DeviceSymbolEntry(4, 'Missile', 'SetBootPos'),
    DeviceSymbolEntry(5, 'Missile', 'SetStackPos'),
    DeviceSymbolEntry(6, 'Missile', 'FireMissile'),
  ],
  19: [ // Beamer
    DeviceSymbolEntry(0, 'Beam', 'GetDir'),
    DeviceSymbolEntry(1, 'Beam', 'GetLength'),
    DeviceSymbolEntry(4, 'Beam', 'FireBeam'),
    DeviceSymbolEntry(5, 'Beam', 'SetBeamDir'),
    DeviceSymbolEntry(6, 'Beam', 'SetBeamLength'),
  ],
  20: [ // RocketLauncher
    DeviceSymbolEntry(0, 'Rocket', 'GetReadiness'),
    DeviceSymbolEntry(1, 'Rocket', 'GetDistance'),
    DeviceSymbolEntry(4, 'Rocket', 'SetDistance'),
    DeviceSymbolEntry(5, 'Rocket', 'FireRocket'),
  ],
};
