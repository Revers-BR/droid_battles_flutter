import 'dart:typed_data';

import 'package:droid_battles/battle/battle_config.dart';
import 'package:droid_battles/battle/text_mode_battle_area.dart';
import 'package:droid_battles/core/screen_object.dart';
import 'package:droid_battles/vm/common_symbols.dart' as sym;
import 'package:droid_battles/vm/instruction.dart';
import 'package:droid_battles/vm/ram.dart';
import 'package:droid_battles/vm/rob_cpu.dart';
import 'package:flutter_test/flutter_test.dart';

// Testes de fumaca escritos SEM poder rodar (o ambiente onde o porte
// foi feito nao tem SDK Dart/Flutter). Rode com `flutter test` e
// corrija o que falhar -- uma falha aqui provavelmente e bug do porte.

RobCpu _cpuWith(List<int> program, {int level = 8}) {
  const boot = 16;
  final file = Uint8List(256 + 1024);
  for (var i = 0; i < program.length; i++) {
    file[256 + boot + i] = program[i];
  }
  return RobCpu(
    mem: Ram.fromBotFile(1024, file),
    owner: ScreenObject(),
    level: level,
    bootMemLow: boot,
    bootMemHigh: 0,
    stackMemLow: 0,
    stackMemHigh: 2, // pilha em 512
    randomSeed: 1,
  );
}

void main() {
  test('tabela de instrucoes tem 247 entradas', () {
    expect(kInstructionTable.length, 247);
  });

  test('Ram: endereco 0 le 0xFF (comportamento do original)', () {
    final ram = Ram.fromBotFile(1024, Uint8List(256 + 1024));
    expect(ram.getByte(0), 0xFF);
    ram.setWord(10, 0x1234);
    expect(ram.getByte(10), 0x34);
    expect(ram.getWord(10), 0x1234);
  });

  test('mov ax,5 ; add ax,3  =>  ax == 8', () {
    final cpu = _cpuWith([
      0x0B, sym.ax, 5, 0, // mov ax,5
      0x5A, sym.ax, 3, 0, // add ax,3
    ]);
    cpu.execute();
    expect(cpu.registers.getWord(sym.ax), 8);
  });

  test('sub / xor / shl', () {
    final cpu = _cpuWith([
      0x0B, sym.bx, 10, 0, // mov bx,10
      0x6A, sym.bx, 4, 0, // sub bx,4      -> 6
      0xBA, sym.bx, 3, 0, // xor bx,3      -> 5
      0xC8, sym.bx, 2, // shl bx,2         -> 20
    ]);
    cpu.execute();
    expect(cpu.registers.getWord(sym.bx), 20);
  });

  test('cmp + jz pula quando igual', () {
    final cpu = _cpuWith([
      0x0B, sym.cx, 7, 0, // mov cx,7
      0x35, sym.cx, 7, 0, // cmp cx,7   -> equal
      0x3D, 40, 0, // jz 40
    ]);
    cpu.execute();
    // Depois do salto a CPU executa nops a partir de 40 ate acabar os ciclos.
    expect(cpu.registers.getWord(sym.eip) >= 40, isTrue);
  });

  test('arena sem bots termina na primeira rodada (retorno 3)', () {
    final area = TextModeBattleArea(BattleConfig(randomSeed: 42));
    expect(area.execRound(), 3);
  });
}
