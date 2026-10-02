import 'dart:typed_data';

import '../vm/common_symbols.dart';
import '../vm/instruction.dart';
import '../vm/ram.dart';
import 'device_symbols.dart';

// Porte de `CreateBot::assemble()` (src/createbot.cpp, droidbattles
// original) -- o assembler de verdade, texto -> bytecode. E uma
// passada so: labels/consts/vars entram na mesma tabela de simbolos
// na hora em que aparecem (entao uma referencia PRA TRAS ja resolve
// na hora), e uma referencia PRA FRENTE (label ainda nao visto) fica
// numa lista de pendencias, resolvida no final quando todos os
// labels ja existem.
//
// Fica de fora (so UI, Qt): o editor de texto em si, realce de
// sintaxe, e o "showlatency" (painel lateral com o numero de ciclos
// de cada instrucao) -- isso e responsabilidade da tela mobile.
//
// BUG CONHECIDO DO ORIGINAL, replicado aqui de proposito: a forma de
// 3 operandos `mov reg,@regref,valor` / `mov @regref,valor,reg`
// (usada bem raramente) usa os indices LITERAIS 245/246 na tabela de
// instrucoes pra pegar o opcode -- mas esses indices na tabela real
// sao "cj"/"cjn" (0xF1/0xF2), nao os opcodes 0xEA/0xEB que de fato
// implementam mov-com-offset (esses ficam nos indices 236/237). Ou
// seja, o assembler ORIGINAL emite o opcode ERRADO pra essa forma de
// mov -- um bug real do jogo, nao um erro de porte. Replicado aqui
// fielmente; ver `_matchThreeOperandMov`. Consequencia direta: como a
// busca normal de mnemonico so varre os indices 0..244 da tabela
// (`for i<245`), as mnemonicas "cj"/"cjn" propriamente ditas (indices
// 245/246) NUNCA batem por matching normal -- so saem acidentalmente
// atraves dessa forma de mov de 3 operandos. No jogo original nao da
// pra montar um `cj`/`cjn` "de verdade" via assembly comum.

class DeviceSlot {
  const DeviceSlot({this.type = 0, this.level = 0, this.arg1 = 0});
  final int type; // 0 = vazio, 1 = CPU, ... 20 = RocketLauncher
  final int level; // 0-4
  final int arg1; // byte (porta/offset/nivel inicial; CPU ignora, usa %CPUboot/%CPUstack)
}

class AssembleError {
  AssembleError(this.message, this.line);
  final String message;

  /// Linha (0-based) onde o erro ocorreu, ou null se nao for
  /// associado a uma linha especifica.
  final int? line;

  @override
  String toString() => line == null ? message : 'Linha ${line! + 1}: $message';
}

class AssembleResult {
  AssembleResult.ok(this.mem, this.debugMem, this.debugLines) : error = null;
  AssembleResult.fail(this.error)
      : mem = null,
        debugMem = const [],
        debugLines = const [];

  /// `mem` pronto pro `Robots(..., botFileBytes: mem)` -- 256 bytes de
  /// header + a RAM do tamanho escolhido. Passe por
  /// `BotFile.addFraming` antes de salvar num arquivo `.bot` de verdade.
  final Uint8List? mem;
  final AssembleError? error;

  /// Paralelos: endereco de memoria de cada instrucao emitida e a
  /// linha fonte correspondente (pra um futuro depurador mostrar
  /// "voce esta na linha X").
  final List<int> debugMem;
  final List<int> debugLines;

  bool get success => error == null;
}

class Assembler {
  const Assembler._();

  static const int _maxSymbols = 2048;
  static const int _maxUnresolved = 4096;

  /// Monta o texto assembly em `source` num `.bot` (so o `mem`, sem o
  /// framing de arquivo). [ramSizeIndex] e o indice em
  /// `Ram.sizeOptions` (0-8); [devices] deve ter exatamente 32
  /// posicoes (slots vazios = `DeviceSlot()`, tipo 0).
  static AssembleResult assemble({
    required String source,
    required int ramSizeIndex,
    required List<DeviceSlot> devices,
  }) {
    assert(devices.length == 32);
    final ramAmount = Ram.sizeOptions[ramSizeIndex.clamp(0, Ram.sizeOptions.length - 1)];
    final memSize = ramAmount + 256 + 1; // +1: o sentinel escrito (e descartado) no final
    final mem = Uint8List(memSize);

    final names = List<String>.filled(_maxSymbols, '');
    final nvalues = List<int>.filled(_maxSymbols, 0);
    final existn = List<bool>.filled(_maxSymbols, false);

    final unresn = List<String>.filled(_maxUnresolved, '');
    final unrespos = List<int>.filled(_maxUnresolved, 0);
    final unresexist = List<bool>.filled(_maxUnresolved, false);
    final unresbits = List<int>.filled(_maxUnresolved, 0);
    final unresline = List<int>.filled(_maxUnresolved, 0);

    final debugMem = <int>[];
    final debugLines = <int>[];

    mem[0] = 0x42; // 'B'
    mem[1] = ramSizeIndex;

    // Tabela de devices + simbolos automaticos (ex.: "Scanner0_Scan").
    final numSortDec = List<int>.filled(21, 0);
    int nextFreeSymbol() {
      for (var x = 0; x < _maxSymbols; x++) {
        if (!existn[x]) return x;
      }
      throw StateError('Tabela de símbolos cheia');
    }

    for (var i = 0; i < 32; i++) {
      final d = devices[i];
      mem[2 + i * 6] = d.type & 0xFF;
      mem[3 + i * 6] = d.level & 0xFF;
      mem[4 + i * 6] = d.arg1 & 0xFF;

      final entries = kDeviceSymbolTable[d.type];
      if (entries == null) continue;
      final n = numSortDec[d.type];
      for (final e in entries) {
        final slot = nextFreeSymbol();
        names[slot] = '${e.prefix}${n}_${e.suffix}';
        nvalues[slot] = i * 4 + (e.slot % 4);
        existn[slot] = true;
      }
      numSortDec[d.type] = n + 1;
    }

    var posInMem = 0;

    AssembleResult? fail(String msg, int? line) => AssembleResult.fail(AssembleError(msg, line));

    final lines = source.split('\n');
    for (var lineNum = 0; lineNum < lines.length; lineNum++) {
      final rawLine = lines[lineNum];
      if (rawLine.isEmpty) continue;

      // Corta comentario (`;` em diante) e espacos/lixo antes do
      // primeiro caractere valido.
      var curLine = rawLine.split(RegExp('[;\r]')).first;
      final firstValid = RegExp(r'[a-zA-Z0-9_#:%@$]').firstMatch(curLine);
      if (firstValid == null) continue;
      curLine = curLine.substring(firstValid.start);
      if (curLine.length <= 1) continue;

      final token = List<String>.filled(16, '');
      final exist = List<bool>.filled(16, false);
      final type = List<InstrType?>.filled(16, null);
      final value = List<List<int>>.generate(16, (_) => [0, 0]);
      final tUnres = List<bool>.filled(16, false);
      final unresNum = List<int>.filled(16, 0);
      var bits = 0;

      // "db" com string entre aspas: cada char vira um token decimal.
      if (curLine.startsWith('db') && 'db'.length < curLine.length && '"'.allMatches(curLine).length == 2) {
        final parts = curLine.split('"');
        token[0] = 'db';
        exist[0] = true;
        final str = parts.length > 1 ? parts[1] : '';
        for (var i = 0; i < str.length && i < 15; i++) {
          token[i + 1] = str.codeUnitAt(i).toString();
          exist[i + 1] = true;
        }
      } else {
        final tokens = curLine.split(RegExp(r'[\s,\x00]+')).where((t) => t.isNotEmpty).toList();
        for (var i = 0; i < tokens.length && i < 16; i++) {
          token[i] = tokens[i];
          exist[i] = true;
        }
      }

      String curMnem = '';

      // --- label ---
      // Sintaxe: SÓ a declaração leva ":" (ex.: ":loop"). Referenciar
      // o label em outra instrução (jmp, cj, etc.) usa o nome SEM o
      // ":" (ex.: "jmp loop") -- é um token "value" comum, resolvido
      // contra a mesma tabela de símbolos.
      if (token[0].startsWith(':')) {
        if (token[0].length <= 1) return fail('Expected: name of label', lineNum)!;
        type[0] = InstrType.label;
        final slot = nextFreeSymbol();
        names[slot] = token[0].substring(1);
        nvalues[slot] = posInMem;
        existn[slot] = true;
        if (exist[1]) return fail('Expected: only one token', lineNum)!;
      }

      // --- const decl (#nome) -- vira um LABEL apontando pra posInMem atual ---
      if (type[0] == null && token[0].startsWith('#')) {
        if (token[0].length <= 1) return fail('Expected: name of variable', lineNum)!;
        type[0] = InstrType.constDecl;
        final slot = nextFreeSymbol();
        names[slot] = token[0].substring(1);
        nvalues[slot] = posInMem;
        existn[slot] = true;
        if (exist[1]) return fail('Expected: only one token', lineNum)!;
      }

      // --- var decl ($nome valor) -- uma constante com valor literal ---
      if (type[0] == null && token[0].startsWith('\$')) {
        if (token[0].length <= 1) return fail('Expected: name of constant', lineNum)!;
        type[0] = InstrType.varDecl;
        final slot = nextFreeSymbol();
        names[slot] = token[0].substring(1);
        existn[slot] = true;
        if (!exist[1]) return fail('Expected: value of constant', lineNum)!;
        nvalues[slot] = int.tryParse(token[1]) ?? 0;
        if (exist[2]) return fail('Expected: only two tokens', lineNum)!;
      }

      // --- db ---
      if (type[0] == null && token[0] == 'db') {
        type[0] = InstrType.db;
        for (var i = 1; i < 15; i++) {
          if (!exist[i]) continue;
          final v = int.tryParse(token[i]);
          if (v == null) {
            for (var x = 0; x < _maxSymbols; x++) {
              if (existn[x] && token[i] == names[x]) {
                mem[posInMem + 256] = nvalues[x] & 0xFF;
                posInMem++;
              }
            }
          } else {
            mem[posInMem + 256] = v & 0xFF;
            posInMem++;
          }
        }
      }

      // --- dw ---
      if (type[0] == null && token[0] == 'dw') {
        type[0] = InstrType.db;
        for (var i = 1; i < 15; i++) {
          if (!exist[i]) continue;
          final v = int.tryParse(token[i]);
          if (v == null) {
            for (var x = 0; x < _maxSymbols; x++) {
              if (existn[x] && token[i] == names[x]) {
                mem[posInMem + 256] = nvalues[x] % 256;
                mem[posInMem + 257] = nvalues[x] ~/ 256;
                posInMem += 2;
              }
            }
          } else {
            final vv = v < 0 ? v + 65536 : v;
            mem[posInMem + 256] = vv % 256;
            mem[posInMem + 257] = (vv ~/ 256) & 0xFF;
            posInMem += 2;
          }
        }
      }

      // --- %org ---
      if (type[0] == null && token[0] == '%org') {
        type[0] = InstrType.offset;
        if (!exist[1]) return fail('Expected: value or symbol', lineNum)!;
        final isPlus = token[1].startsWith('+');
        final comp = isPlus ? token[1].substring(1) : token[1];
        final v = int.tryParse(comp);
        if (v == null) {
          var found = false;
          for (var x = 0; x < _maxSymbols; x++) {
            if (existn[x] && token[1] == names[x]) {
              posInMem = nvalues[x];
              found = true;
            }
          }
          if (!found) return fail('Unknown symbol', lineNum)!;
        } else {
          posInMem = isPlus ? posInMem + v : v;
        }
      }

      // --- %CPUboot / %CPUstack ---
      void writeCpuHeaderField(int byteOffsetInSlot, String directive) {
        if (!exist[1]) return;
        final v = int.tryParse(token[1]);
        int devNum;
        if (v == null) {
          devNum = -1;
          for (var x = 0; x < _maxSymbols; x++) {
            if (existn[x] && token[1] == names[x]) devNum = nvalues[x];
          }
          if (devNum == -1) return; // erro reportado abaixo
        } else {
          devNum = v;
        }
        if (devNum < 0 || devNum >= 32 || mem[devNum * 6 + 2] != 1) return;
        mem[devNum * 6 + byteOffsetInSlot] = posInMem % 256;
        mem[devNum * 6 + byteOffsetInSlot + 1] = (posInMem ~/ 256) & 0xFF;
      }

      if (type[0] == null && token[0] == '%CPUboot') {
        type[0] = InstrType.cpuBoot;
        if (!exist[1]) return fail('Expected: number of CPU device', lineNum)!;
        final v = int.tryParse(token[1]);
        final devNum = v ?? nvalues.asMap().entries.firstWhere(
              (e) => existn[e.key] && names[e.key] == token[1],
              orElse: () => const MapEntry(-1, -1),
            ).value;
        if (devNum < 0 || devNum >= 32 || mem[devNum * 6 + 2] != 1) {
          return fail('Value must be the number of a CPU device', lineNum)!;
        }
        writeCpuHeaderField(4, '%CPUboot');
      }

      if (type[0] == null && token[0] == '%CPUstack') {
        type[0] = InstrType.cpuStack;
        if (!exist[1]) return fail('Expected: number of CPU device', lineNum)!;
        final v = int.tryParse(token[1]);
        final devNum = v ?? nvalues.asMap().entries.firstWhere(
              (e) => existn[e.key] && names[e.key] == token[1],
              orElse: () => const MapEntry(-1, -1),
            ).value;
        if (devNum < 0 || devNum >= 32 || mem[devNum * 6 + 2] != 1) {
          return fail('Value must be the number of a CPU device', lineNum)!;
        }
        writeCpuHeaderField(6, '%CPUstack');
      }

      // --- %interrupt ---
      if (type[0] == null && token[0] == '%interrupt') {
        type[0] = InstrType.interrupt;
        if (!exist[1]) return fail('Expected: number of interrupt', lineNum)!;
        final v = int.tryParse(token[1]);
        int interNum;
        if (v == null) {
          interNum = -1;
          for (var x = 0; x < _maxSymbols; x++) {
            if (existn[x] && token[1] == names[x]) interNum = nvalues[x];
          }
          if (interNum == -1) return fail('Unknown symbol', lineNum)!;
        } else {
          interNum = v;
        }
        if (interNum > 255) return fail('Value must be lower than 256', lineNum)!;
        mem[ramAmount + 256 - (interNum * 2 + 2)] = posInMem % 256;
        mem[ramAmount + 256 - (interNum * 2 + 1)] = (posInMem ~/ 256) & 0xFF;
      }

      // --- mnemonico (instrucao de verdade) ---
      if (type[0] == null) {
        type[0] = InstrType.mnemonic;
        curMnem = token[0];
      }

      if (type[0] == InstrType.mnemonic) {
        // registradores
        for (var i = 1; i < 4; i++) {
          if (!exist[i] || type[i] != null) continue;
          final reg = _registerByName[token[i]];
          if (reg != null) {
            type[i] = InstrType.register;
            value[i][0] = reg.$1;
            bits = reg.$2;
          }
        }
        // @registrador (registerref)
        for (var i = 1; i < 3; i++) {
          if (!exist[i] || type[i] != null || !token[i].startsWith('@')) continue;
          final reg = _registerByName[token[i].substring(1)];
          if (reg != null) {
            type[i] = InstrType.registerRef;
            value[i][0] = reg.$1;
          }
        }
        // byte/word (bit identifier)
        for (var i = 1; i < 3; i++) {
          if (!exist[i] || type[i] != null) continue;
          if (token[i] == 'byte') {
            type[i] = InstrType.bitId;
            value[i][0] = 8;
            bits = 8;
          } else if (token[i] == 'word') {
            type[i] = InstrType.bitId;
            value[i][0] = 16;
            bits = 16;
          }
        }
        // @valor (memaddress)
        for (var i = 1; i < 3; i++) {
          if (!exist[i] || type[i] != null || !token[i].startsWith('@')) continue;
          final sym = token[i].substring(1);
          final v = int.tryParse(sym);
          if (v == null) {
            var found = false;
            for (var x = 0; x < _maxSymbols; x++) {
              if (existn[x] && sym == names[x]) {
                value[i][0] = nvalues[x] % 256;
                value[i][1] = nvalues[x] ~/ 256;
                type[i] = InstrType.memAddress;
                found = true;
              }
            }
            if (!found) {
              type[i] = InstrType.memAddress;
              tUnres[i] = true;
              final slot = _nextFreeUnresolved(unresexist);
              unresexist[slot] = true;
              unresn[slot] = sym;
              unresline[slot] = lineNum;
              unresNum[i] = slot;
            }
          } else {
            value[i][0] = v % 256;
            value[i][1] = v ~/ 256;
            type[i] = InstrType.memAddress;
          }
        }
        // valor (imediato)
        for (var i = 1; i < 4; i++) {
          if (!exist[i] || type[i] != null) continue;
          final isPlus = token[i].startsWith('+');
          final comp = isPlus ? token[i].substring(1) : token[i];
          final v = int.tryParse(comp);
          if (v == null) {
            var found = false;
            for (var x = 0; x < _maxSymbols; x++) {
              if (existn[x] && comp == names[x]) {
                value[i][0] = nvalues[x] % 256;
                value[i][1] = nvalues[x] ~/ 256;
                type[i] = InstrType.value;
                found = true;
              }
            }
            if (!found) {
              type[i] = InstrType.value;
              tUnres[i] = true;
              final slot = _nextFreeUnresolved(unresexist);
              unresexist[slot] = true;
              unresn[slot] = token[i];
              unresline[slot] = lineNum;
              unresNum[i] = slot;
            }
          } else {
            final vv = v < 0 ? v + 65536 : v;
            value[i][0] = vv % 256;
            value[i][1] = (vv ~/ 256) & 0xFF;
            type[i] = InstrType.value;
          }
        }

        int instrIndex;
        if (curMnem == 'mov' &&
            type[1] == InstrType.register &&
            type[2] == InstrType.registerRef &&
            type[3] == InstrType.value) {
          // Forma de 3 operandos "mov reg,@regref,valor" -- ver o
          // aviso de bug no topo do arquivo: o original usa o indice
          // LITERAL 245 (nao um opcode calculado), que por acidente
          // aponta pra outra instrucao ("cj"). Replicado de proposito.
          value[1][1] = value[2][0];
          value[2][0] = value[3][0];
          instrIndex = 245;
          if (tUnres[3]) {
            return fail("Sorry, this instruction can't use symbols not declared yet", lineNum)!;
          }
        } else if (curMnem == 'mov' &&
            type[1] == InstrType.registerRef &&
            type[2] == InstrType.value &&
            type[3] == InstrType.register) {
          // idem, indice literal 246 ("cjn").
          value[1][1] = value[2][0];
          value[2][0] = value[3][0];
          instrIndex = 246;
          if (tUnres[2]) {
            return fail("Sorry, this instruction can't use symbols not declared yet", lineNum)!;
          }
        } else {
          var found = -1;
          for (var i = 0; i < 245; i++) {
            if (kInstructionTable[i].checkMatch(curMnem, type[1] ?? InstrType.none, type[2] ?? InstrType.none, bits)) {
              found = i;
              break;
            }
          }
          if (found == -1) {
            return fail('Error: unknown mnemonic/operand combination', lineNum)!;
          }
          instrIndex = found;
        }

        final instr = kInstructionTable[instrIndex];
        mem[posInMem + 256] = instr.opcode;
        debugMem.add(posInMem);
        debugLines.add(lineNum);
        posInMem++;

        void emitArg(int argIdx, int argBits) {
          if (tUnres[argIdx]) {
            unrespos[unresNum[argIdx]] = posInMem;
            if (argBits > 0) {
              unresbits[unresNum[argIdx]] = 8;
              posInMem++;
            }
            if (argBits > 8) {
              unresbits[unresNum[argIdx]] = 16;
              posInMem++;
            }
          } else {
            if (argBits > 0) {
              mem[posInMem + 256] = value[argIdx][0];
              posInMem++;
            }
            if (argBits > 8) {
              mem[posInMem + 256] = value[argIdx][1];
              posInMem++;
            }
          }
        }

        emitArg(1, instr.arg1Bits);
        emitArg(2, instr.arg2Bits);
      }
    }

    // Sentinela de fim (era `mem[RAMAMOUNT+256]=255`; nunca chega a
    // ser salvo no arquivo -- o original grava so RAMAMOUNT+256
    // bytes -- entao e so um resquicio inofensivo do original).
    mem[ramAmount + 256] = 255;

    // Resolve as referencias pendentes (labels usados antes de serem
    // declarados).
    for (var i = 0; i < _maxUnresolved; i++) {
      if (!unresexist[i]) continue;
      var resolved = false;
      for (var x = 0; x < _maxSymbols; x++) {
        if (existn[x] && names[x] == unresn[i]) {
          resolved = true;
          if (unresbits[i] == 16) {
            mem[unrespos[i] + 256] = nvalues[x] % 256;
            mem[unrespos[i] + 257] = (nvalues[x] ~/ 256) & 0xFF;
          } else {
            mem[unrespos[i] + 256] = nvalues[x] % 256;
          }
        }
      }
      if (!resolved) {
        return fail('Undeclared symbol: ${unresn[i]}', unresline[i])!;
      }
    }

    return AssembleResult.ok(Uint8List.sublistView(mem, 0, ramAmount + 256), debugMem, debugLines);
  }

  static int _nextFreeUnresolved(List<bool> unresexist) {
    for (var x = 0; x < _maxUnresolved; x++) {
      if (!unresexist[x]) return x;
    }
    throw StateError('Tabela de referências pendentes cheia');
  }
}

/// Nome -> (índice do registrador, tamanho em bits). Era a cascata de
/// `if (token[i]=="ax") {...}` em createbot.cpp.
const Map<String, (int, int)> _registerByName = {
  'ax': (ax, 16),
  'bx': (bx, 16),
  'cx': (cx, 16),
  'dx': (dx, 16),
  'sp': (sp, 16),
  'bp': (bp, 16),
  'si': (si, 16),
  'di': (di, 16),
  'eip': (eip, 16),
  'flags': (0, 16),
  'ah': (ah, 8),
  'al': (al, 8),
  'bh': (bh, 8),
  'bl': (bl, 8),
  'ch': (ch, 8),
  'cl': (cl, 8),
  'dh': (dh, 8),
  'dl': (dl, 8),
};
