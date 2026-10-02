import 'dart:math' as math;

import '../core/screen_object.dart';
import '../persistence/bot_file_access.dart';
import 'common_symbols.dart';
import 'cpu.dart';
import 'debug_contents.dart';
import 'ram.dart';

// Porte de src/robcpu.h e src/robcpu.cpp (droidbattles original).
//
// STATUS DESTA PORTAGEM: os 247 opcodes (0x00-0xF2) estao todos
// portados byte a byte a partir do `switch` original em robcpu.cpp
// (linhas ~405-2604), junto com registradores, tabela de latencia,
// loop de interrupcao (`execute()`) e loop de busca/decodificacao
// (`execInstr`). Duas ressalvas conhecidas, ambas comentadas no local:
// - `readFile`/`writeFile` (opcodes 0x93/0x94) dependem da camada de
//   persistencia do arquivo .bot do robo, ainda nao portada (ver
//   cpu.dart) -- por enquanto sempre retornam -1.
// - 0xD4 (ISHL reg,imm) reproduz um deslocamento duplicado que existe
//   no C++ original (ver comentario no case).
//
// Ainda faltam nesta VM: a integracao real de interrupcoes (hoje
// `execute()` recebe o pedido de interrupcao "de fora" via parametros,
// em vez de vir da fila de portas do device, que faz parte do porte
// de `device.dart`/`robots.dart`) e testes automatizados comparando a
// saida com o binario original.
class RobCpu extends Cpu {
  /// Gerador de numeros aleatorios usado pelo opcode RND (era
  /// `std::mt19937 m_randomness` + `uniform_int_distribution<uint16_t>`
  /// no C++ original).
  final math.Random _random;

  /// Era a variavel global `SingleStepMode` (definida em battlearea.h),
  /// checada no fim de cada instrucao pra permitir "andar" uma
  /// instrucao por vez no depurador. Exposta aqui como campo da
  /// instancia em vez de global.
  bool singleStepMode = false;

  RobCpu({
    required Ram mem,
    required ScreenObject owner,
    required int level,
    required int bootMemLow,
    required int bootMemHigh,
    required int stackMemLow,
    required int stackMemHigh,
    int? randomSeed,
    BotFileAccess? fileAccess,
  })  : _random = randomSeed == null ? math.Random() : math.Random(randomSeed),
        super(mem, owner, fileAccess: fileAccess) {
    speed = level;
    bootMem = bootMemLow + bootMemHigh * 256;
    stackMem = stackMemLow + stackMemHigh * 256;
    registers.setWord(eip, bootMem);
    registers.setWord(sp, stackMem);

    // Tabela de latencia por opcode, extraida 1:1 do construtor
    // original (RobCpu::RobCpu, instrlatency[0..242]); opcodes nao
    // usados pelo jogo (243-255) ficam em 0, igual ao original.
    const latency = <int>[
      1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 2, 2, 2,
      2, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 1, 1, 1, 1, 2,
      2, 2, 2, 1, 1, 2, 2, 2, 2, 1, 2, 2, 1, 2, 2, 1,
      1, 2, 2, 2, 2, 1, 1, 2, 2, 2, 2, 5, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 3, 3, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2,
      2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 2, 2, 2, 2,
      2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 2, 2, 2, 2, 1, 1,
      2, 2, 2, 2, 4, 5, 1, 1, 8, 7, 1, 1, 1, 1, 2, 2,
      0, 0, 0, 100, 100, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2,
      2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 2, 2, 2, 2,
      2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 2, 2, 2, 2,
      2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
      2, 4, 5, 1, 1, 1, 13, 13, 8, 8, 2, 2, 5, 0, 1, 1,
      1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ];
    for (var i = 0; i < latency.length; i++) {
      instrLatency[i] = latency[i];
    }
    cyclesLeft = 0;
  }

  /// Era `RobCpu::execute()`: soma ciclos, checa se ha uma interrupcao
  /// pendente na PORTA 0 do proprio device (fila herdada de `Device`,
  /// preenchida por `Robots::addInterrupt` via `addInputPort(0, ...)`)
  /// e, se houver, desvia pro vetor de interrupcao antes de executar.
  @override
  void execute() {
    cyclesLeft += speed;
    if (stackTaken[0][0]) {
      final inter = portStack[0][0];
      movePortStack(0);

      final temp = mem.returnSize() - (inter * 2 + 2); // endereco do vetor de interrupcao
      if (mem.getWord(temp) != 0xFFFF) {
        mem.setWord(registers.getWord(sp), registers.getWord(eip)); // salva eip na pilha
        final tt = mem.returnSize();
        registers.setWord(eip, mem.getWord(tt - (inter * 2 + 2)));
        registers.incWord(sp, 2);
        registers.setWord(flagsReg, registers.getWord(flagsReg) & 0xFBFF); // limpa flag de interrupcao
      }
    }
    execInstr();
  }

  int type() => cpuType;

  /// Era `RobCpu::debugContents()` -- usado pela tela de depuração
  /// (ver ui/debug_screen.dart).
  DebugContents debugContents() {
    List<int> around(int center) => [for (var x = -4; x < 5; x++) mem.getByte(center + x)];
    return DebugContents(
      flags: registers.getWord(flagsReg),
      ax: registers.getWord(ax),
      bx: registers.getWord(bx),
      cx: registers.getWord(cx),
      dx: registers.getWord(dx),
      sp: registers.getWord(sp),
      si: registers.getWord(si),
      di: registers.getWord(di),
      bp: registers.getWord(bp),
      ip: registers.getWord(eip),
      ipContents: around(registers.getWord(eip)),
      spContents: around(registers.getWord(sp)),
      siContents: around(registers.getWord(si)),
      diContents: around(registers.getWord(di)),
      execMem: List<int>.from(lastExecMem),
    );
  }

  /// Era `RobCpu::specialValue()`.
  int specialValue() => (registers.getWord(flagsReg) & 0x0400) == 0x0400 ? cpuWithInt : 4;

  @override
  void sendMsg(String msg) => ourbot!.sendMessage(msg);

  @override
  void execInstr() {
    for (var x = 0; x < lastExecMem.length; x++) {
      lastExecMem[x] = -1;
    }
    var execMemEntry = 0;

    while (cyclesLeft > 0) {
      final ip = registers.getWord(eip);
      final instr = mem.getByte(ip);
      if (execMemEntry < lastExecMem.length) {
        lastExecMem[execMemEntry++] = ip;
      }
      cyclesLeft -= instrLatency[instr];

      switch (instr) {
        case 0x00: // nop
          registers.incWord(eip);
          break;

        // ---- mov ----
        case 0x01: // mov reg,reg 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0x02: // mov reg,reg 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0x03: // mov reg,mem 16
          registers.setWord(mem.getByte(ip + 1), mem.getWord(mem.getWord(ip + 2)));
          registers.incWord(eip, 4);
          break;
        case 0x04: // mov reg,mem 8
          registers.setByte(mem.getByte(ip + 1), mem.getByte(mem.getWord(ip + 2)));
          registers.incWord(eip, 4);
          break;
        case 0x05: // mov reg,[reg] 16
          registers.setWord(mem.getByte(ip + 1), mem.getWord(registers.getWord(mem.getByte(ip + 2))));
          registers.incWord(eip, 3);
          break;
        case 0x06: // mov reg,[reg] 8
          registers.setByte(mem.getByte(ip + 1), mem.getByte(registers.getWord(mem.getByte(ip + 2))));
          registers.incWord(eip, 3);
          break;
        case 0x07: // mov mem,reg 16
          mem.setWord(mem.getWord(ip + 1), registers.getWord(mem.getByte(ip + 3)));
          registers.incWord(eip, 4);
          break;
        case 0x08: // mov mem,reg 8
          mem.setByte(mem.getWord(ip + 1), registers.getByte(mem.getByte(ip + 3)));
          registers.incWord(eip, 4);
          break;
        case 0x09: // mov [reg],reg 16
          mem.setWord(registers.getWord(mem.getByte(ip + 1)), registers.getWord(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0x0A: // mov [reg],reg 8
          mem.setByte(registers.getWord(mem.getByte(ip + 1)), registers.getByte(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0x0B: // mov reg,imm 16
          registers.setWord(mem.getByte(ip + 1), mem.getWord(ip + 2));
          registers.incWord(eip, 4);
          break;
        case 0x0C: // mov reg,imm 8
          registers.setByte(mem.getByte(ip + 1), mem.getByte(ip + 2));
          registers.incWord(eip, 3);
          break;
        case 0x0D: // mov [reg],imm 16
          mem.setWord(registers.getWord(mem.getByte(ip + 1)), mem.getWord(ip + 2));
          registers.incWord(eip, 4);
          break;
        case 0x0E: // mov [reg],imm 8
          mem.setByte(registers.getWord(mem.getByte(ip + 1)), mem.getByte(ip + 2));
          registers.incWord(eip, 3);
          break;
        case 0x0F: // mov mem,imm 16
          mem.setWord(mem.getWord(ip + 1), mem.getWord(ip + 3));
          registers.incWord(eip, 5);
          break;
        case 0x10: // mov mem,imm 8
          mem.setByte(mem.getWord(ip + 1), mem.getByte(ip + 3));
          registers.incWord(eip, 4);
          break;

        // ---- string ops ----
        case 0x11: // movsb
          {
            final count = registers.getWord(cx);
            for (var x = 0; x < count; x++) {
              mem.setByte(registers.getWord(di), mem.getByte(registers.getWord(si)));
              registers.incWord(di);
              registers.incWord(si);
            }
            registers.incWord(eip);
          }
          break;
        case 0x12: // movsw
          {
            final count = registers.getWord(cx);
            for (var x = 0; x < count; x++) {
              mem.setWord(registers.getWord(di), mem.getWord(registers.getWord(si)));
              registers.incWord(di, 2);
              registers.incWord(si, 2);
            }
            registers.incWord(eip);
          }
          break;
        case 0x13: // stosb
          {
            final count = registers.getWord(cx);
            for (var x = 0; x < count; x++) {
              mem.setByte(registers.getWord(di), registers.getByte(ah));
              registers.incWord(di);
            }
            registers.incWord(eip);
          }
          break;
        case 0x14: // stosw
          {
            final count = registers.getWord(cx);
            for (var x = 0; x < count; x++) {
              mem.setWord(registers.getWord(di), registers.getWord(ax));
              registers.incWord(di, 2);
            }
            registers.incWord(eip);
          }
          break;

        // ---- push/pop ----
        case 0x15: // push r 16
          mem.setWord(registers.getWord(sp), registers.getWord(mem.getByte(ip + 1)));
          registers.incWord(sp, 2);
          registers.incWord(eip, 2);
          break;
        case 0x16: // push r 8
          mem.setByte(registers.getWord(sp), registers.getByte(mem.getByte(ip + 1)));
          registers.incWord(sp);
          registers.incWord(eip, 2);
          break;
        case 0x17: // push mem 16
          mem.setWord(registers.getWord(sp), mem.getWord(mem.getWord(ip + 1)));
          registers.incWord(sp, 2);
          registers.incWord(eip, 3);
          break;
        case 0x18: // push mem 8
          mem.setByte(registers.getWord(sp), mem.getByte(mem.getWord(ip + 1)));
          registers.incWord(sp);
          registers.incWord(eip, 3);
          break;
        case 0x19: // push [reg] 16
          mem.setWord(registers.getWord(sp), mem.getWord(registers.getWord(mem.getByte(ip + 1))));
          registers.incWord(sp, 2);
          registers.incWord(eip, 2);
          break;
        case 0x1A: // push [reg] 8
          mem.setByte(registers.getWord(sp), mem.getByte(registers.getWord(mem.getByte(ip + 1))));
          registers.incWord(sp);
          registers.incWord(eip, 2);
          break;
        case 0x1B: // push imm 16
          mem.setWord(registers.getWord(sp), mem.getWord(ip + 1));
          registers.incWord(sp, 2);
          registers.incWord(eip, 3);
          break;
        case 0x1C: // push imm 8
          mem.setByte(registers.getWord(sp), mem.getByte(ip + 1));
          registers.incWord(sp);
          registers.incWord(eip, 2);
          break;
        case 0x1D: // pop reg 16
          registers.decWord(sp, 2);
          registers.setWord(mem.getByte(ip + 1), mem.getWord(registers.getWord(sp)));
          registers.incWord(eip, 2);
          break;
        case 0x1E: // pop reg 8
          registers.decWord(sp);
          registers.setByte(mem.getByte(ip + 1), mem.getByte(registers.getWord(sp)));
          registers.incWord(eip, 2);
          break;
        case 0x1F: // pop mem 16
          registers.decWord(sp, 2);
          mem.setWord(mem.getWord(ip + 1), mem.getWord(registers.getWord(sp)));
          registers.incWord(eip, 3);
          break;
        case 0x20: // pop mem 8
          registers.decWord(sp);
          mem.setByte(mem.getWord(ip + 1), mem.getByte(registers.getWord(sp)));
          registers.incWord(eip, 3);
          break;
        case 0x21: // pop [reg] 16
          registers.decWord(sp, 2);
          mem.setWord(registers.getWord(mem.getByte(ip + 1)), mem.getWord(registers.getWord(sp)));
          registers.incWord(eip, 2);
          break;
        case 0x22: // pop [reg] 8
          registers.decWord(sp);
          mem.setByte(registers.getWord(mem.getByte(ip + 1)), mem.getByte(registers.getWord(sp)));
          registers.incWord(eip, 2);
          break;

        // ---- xchg ----
        case 0x23: // xchg reg,reg 16
          {
            final a = mem.getByte(ip + 1), b = mem.getByte(ip + 2);
            final tmp = registers.getWord(a);
            registers.setWord(a, registers.getWord(b));
            registers.setWord(b, tmp);
            registers.incWord(eip, 3);
          }
          break;
        case 0x24: // xchg reg,reg 8
          {
            final a = mem.getByte(ip + 1), b = mem.getByte(ip + 2);
            final tmp = registers.getByte(a);
            registers.setByte(a, registers.getByte(b));
            registers.setByte(b, tmp);
            registers.incWord(eip, 3);
          }
          break;
        case 0x25: // xchg reg,mem 16
          {
            final a = mem.getByte(ip + 1);
            final addr = mem.getWord(ip + 2);
            final tmp = registers.getWord(a);
            registers.setWord(a, mem.getWord(addr));
            mem.setWord(addr, tmp);
            registers.incWord(eip, 4);
          }
          break;
        case 0x26: // xchg reg,mem 8
          {
            final a = mem.getByte(ip + 1);
            final addr = mem.getWord(ip + 2);
            final tmp = registers.getByte(a);
            registers.setByte(a, mem.getByte(addr));
            mem.setByte(addr, tmp);
            registers.incWord(eip, 4);
          }
          break;
        case 0x27: // xchg reg,[reg] 16
          {
            final a = mem.getByte(ip + 1);
            final addr = registers.getWord(mem.getByte(ip + 2));
            final tmp = registers.getWord(a);
            registers.setWord(a, mem.getWord(addr));
            mem.setWord(addr, tmp);
            registers.incWord(eip, 3);
          }
          break;
        case 0x28: // xchg reg,[reg] 8 (o original marca esse opcode como "broken")
          {
            final a = mem.getByte(ip + 1);
            final addr = registers.getWord(mem.getByte(ip + 2));
            final tmp = registers.getByte(a);
            registers.setByte(a, mem.getByte(addr));
            mem.setByte(addr, tmp);
            registers.incWord(eip, 3);
          }
          break;

        // ---- test (testa 1 bit, seta/limpa equalflag) ----
        case 0x29: // test reg,imm
          _testBit(registers.getWord(mem.getByte(ip + 1)), mem.getByte(ip + 2));
          registers.incWord(eip, 3);
          break;
        case 0x2A: // test mem,imm
          _testBit(mem.getWord(mem.getWord(ip + 1)), mem.getByte(ip + 2));
          registers.incWord(eip, 4);
          break;
        case 0x2B: // test [reg],imm
          _testBit(mem.getWord(registers.getWord(mem.getByte(ip + 1))), mem.getByte(ip + 2));
          registers.incWord(eip, 3);
          break;
        case 0x2C: // test reg,cl
          _testBit(registers.getWord(mem.getByte(ip + 1)), registers.getByte(cl));
          registers.incWord(eip, 2);
          break;
        case 0x2D: // test mem,cl
          _testBit(mem.getWord(mem.getWord(ip + 1)), registers.getByte(cl));
          registers.incWord(eip, 3);
          break;
        case 0x2E: // test [reg],cl
          _testBit(mem.getWord(registers.getWord(mem.getByte(ip + 1))), registers.getByte(cl));
          registers.incWord(eip, 2);
          break;

        // ---- cmp ----
        case 0x2F: // cmp reg,reg 16
          _setCompareFlags(registers.getWord(mem.getByte(ip + 1)), registers.getWord(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0x30: // cmp reg,reg 8
          _setCompareFlags(registers.getByte(mem.getByte(ip + 1)), registers.getByte(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0x31: // cmp reg,mem 16
          _setCompareFlags(registers.getWord(mem.getByte(ip + 1)), mem.getWord(mem.getWord(ip + 2)));
          registers.incWord(eip, 4);
          break;
        case 0x32: // cmp reg,mem 8
          _setCompareFlags(registers.getByte(mem.getByte(ip + 1)), mem.getByte(mem.getWord(ip + 2)));
          registers.incWord(eip, 4);
          break;
        case 0x33: // cmp reg,[reg] 16
          _setCompareFlags(registers.getWord(mem.getByte(ip + 1)), mem.getWord(registers.getWord(mem.getByte(ip + 2))));
          registers.incWord(eip, 3);
          break;
        case 0x34: // cmp reg,[reg] 8
          _setCompareFlags(registers.getByte(mem.getByte(ip + 1)), mem.getByte(registers.getWord(mem.getByte(ip + 2))));
          registers.incWord(eip, 3);
          break;
        case 0x35: // cmp reg,imm 16
          _setCompareFlags(registers.getWord(mem.getByte(ip + 1)), mem.getWord(ip + 2));
          registers.incWord(eip, 4);
          break;
        case 0x36: // cmp reg,imm 8
          _setCompareFlags(registers.getByte(mem.getByte(ip + 1)), mem.getByte(ip + 2));
          registers.incWord(eip, 3);
          break;
        case 0x37: // cmp [reg],imm 16
          _setCompareFlags(mem.getWord(registers.getWord(mem.getByte(ip + 1))), mem.getWord(ip + 2));
          registers.incWord(eip, 4);
          break;
        case 0x38: // cmp [reg],imm 8
          _setCompareFlags(mem.getByte(registers.getWord(mem.getByte(ip + 1))), mem.getByte(ip + 2));
          registers.incWord(eip, 3);
          break;
        case 0x39: // cmp mem,imm 16
          _setCompareFlags(mem.getWord(mem.getWord(ip + 1)), mem.getWord(ip + 3));
          registers.incWord(eip, 5);
          break;
        case 0x3A: // cmp mem,imm 8
          _setCompareFlags(mem.getByte(mem.getWord(ip + 1)), mem.getByte(ip + 2));
          registers.incWord(eip, 4);
          break;
        case 0x3B: // cmpsb
          {
            var status = 0;
            for (var times = registers.getByte(cl); times > 0; times--) {
              final t1 = mem.getByte(registers.getWord(di) + times);
              final t2 = mem.getByte(registers.getWord(si) + times);
              if (t1 != t2) {
                status = t1 > t2 ? 1 : 2;
                break;
              }
            }
            if (status == 0) {
              registers.setWord(flagsReg, (registers.getWord(flagsReg) | setEqualFlag) & clearEqualFlags);
            }
            if (status == 1) {
              registers.setWord(flagsReg, (registers.getWord(flagsReg) | setAboveFlag) & clearAboveFlags);
            }
            if (status == 2) {
              registers.setWord(flagsReg, (registers.getWord(flagsReg) | setBelowFlag) & clearBelowFlags);
            }
            registers.incWord(eip);
          }
          break;

        // ---- jumps / call / ret ----
        case 0x3C: // jmp imm
          registers.setWord(eip, mem.getWord(ip + 1));
          break;
        case 0x3D: // jz imm
          if ((registers.getWord(flagsReg) & equalFlag) == equalFlag) {
            registers.setWord(eip, mem.getWord(ip + 1));
          } else {
            registers.incWord(eip, 3);
          }
          break;
        case 0x3E: // jnz imm
          if ((registers.getWord(flagsReg) & equalFlag) != equalFlag) {
            registers.setWord(eip, mem.getWord(ip + 1));
          } else {
            registers.incWord(eip, 3);
          }
          break;
        case 0x3F: // jae/jnb imm
          if ((registers.getWord(flagsReg) & belowFlag) != belowFlag) {
            registers.setWord(eip, mem.getWord(ip + 1));
          } else {
            registers.incWord(eip, 3);
          }
          break;
        case 0x40: // jbe/jna imm
          if ((registers.getWord(flagsReg) & aboveFlag) != aboveFlag) {
            registers.setWord(eip, mem.getWord(ip + 1));
          } else {
            registers.incWord(eip, 3);
          }
          break;
        case 0x41: // jmp reg
          registers.setWord(eip, registers.getWord(mem.getByte(ip + 1)));
          break;
        case 0x42: // loop imm
          if (registers.getWord(cx) > 0) {
            registers.decWord(cx);
            registers.setWord(eip, mem.getWord(ip + 1));
          } else {
            registers.incWord(eip, 3);
          }
          break;
        case 0x43: // call imm
          mem.setWord(registers.getWord(sp), ip + 3);
          registers.setWord(eip, mem.getWord(ip + 1));
          registers.incWord(sp, 2);
          break;
        case 0x44: // ret
          registers.decWord(sp, 2);
          registers.setWord(eip, mem.getWord(registers.getWord(sp)));
          break;
        case 0x45: // iret
          registers.decWord(sp, 2);
          registers.setWord(eip, mem.getWord(registers.getWord(sp)));
          registers.setWord(flagsReg, registers.getWord(flagsReg) | setInterruptFlag);
          break;

        // ---- interrupt enable/disable ----
        case 0x46: // cli
          registers.setWord(flagsReg, registers.getWord(flagsReg) & clearInterruptFlag);
          registers.incWord(eip);
          break;
        case 0x47: // sti
          registers.setWord(flagsReg, registers.getWord(flagsReg) | setInterruptFlag);
          registers.incWord(eip);
          break;

        // ---- device ports ----
        case 0x48: // out imm,imm
          callObOut(mem.getByte(ip + 1), mem.getWord(ip + 2));
          registers.incWord(eip, 4);
          break;
        case 0x49: // out imm,reg
          callObOut(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0x4A: // out imm,[reg]
          callObOut(mem.getByte(ip + 1), mem.getWord(registers.getWord(mem.getByte(ip + 2))));
          registers.incWord(eip, 3);
          break;
        case 0x4B: // in reg,imm
          registers.setWord(mem.getByte(ip + 1), callObIn(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;

        // ---- inc/dec ----
        case 0x4C: // inc reg 16
          registers.incWord(mem.getByte(ip + 1));
          registers.incWord(eip, 2);
          break;
        case 0x4D: // inc reg 8
          registers.incByte(mem.getByte(ip + 1));
          registers.incWord(eip, 2);
          break;
        case 0x4E: // inc mem 16
          {
            final addr = mem.getWord(ip + 1);
            mem.setWord(addr, mem.getWord(addr) + 1);
            registers.incWord(eip, 3);
          }
          break;
        case 0x4F: // inc mem 8
          {
            final addr = mem.getWord(ip + 1);
            mem.setByte(addr, mem.getByte(addr) + 1);
            registers.incWord(eip, 3);
          }
          break;
        case 0x50: // inc [reg] 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setWord(addr, mem.getWord(addr) + 1);
            registers.incWord(eip, 2);
          }
          break;
        case 0x51: // inc [reg] 8
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setByte(addr, mem.getByte(addr) + 1);
            registers.incWord(eip, 2);
          }
          break;
        case 0x52: // dec reg 16
          registers.decWord(mem.getByte(ip + 1));
          registers.incWord(eip, 2);
          break;
        case 0x53: // dec reg 8
          registers.decByte(mem.getByte(ip + 1));
          registers.incWord(eip, 2);
          break;
        case 0x54: // dec mem 16
          {
            final addr = mem.getWord(ip + 1);
            mem.setWord(addr, mem.getWord(addr) - 1);
            registers.incWord(eip, 3);
          }
          break;
        case 0x55: // dec mem 8
          {
            final addr = mem.getWord(ip + 1);
            mem.setByte(addr, mem.getByte(addr) - 1);
            registers.incWord(eip, 3);
          }
          break;
        case 0x56: // dec [reg] 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setWord(addr, mem.getWord(addr) - 1);
            registers.incWord(eip, 2);
          }
          break;
        case 0x57: // dec [reg] 8
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setByte(addr, mem.getByte(addr) - 1);
            registers.incWord(eip, 2);
          }
          break;

        // ---- add ----
        case 0x58: // add reg,reg 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) + registers.getWord(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0x59: // add reg,reg 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) + registers.getByte(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0x5A: // add reg,imm 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) + mem.getWord(ip + 2));
          registers.incWord(eip, 4);
          break;
        case 0x5B: // add reg,imm 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) + mem.getByte(ip + 2));
          registers.incWord(eip, 3);
          break;
        case 0x5C: // add reg,[reg] 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) + mem.getWord(registers.getWord(mem.getByte(ip + 2))));
          registers.incWord(eip, 3);
          break;
        case 0x5D: // add reg,[reg] 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) + mem.getByte(registers.getWord(mem.getByte(ip + 2))));
          registers.incWord(eip, 3);
          break;
        case 0x5E: // add reg,mem 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) + mem.getWord(mem.getWord(ip + 2)));
          registers.incWord(eip, 4);
          break;
        case 0x5F: // add reg,mem 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) + mem.getByte(mem.getWord(ip + 2)));
          registers.incWord(eip, 4);
          break;
        case 0x60: // add [reg],reg 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setWord(addr, mem.getWord(addr) + registers.getWord(mem.getByte(ip + 2)));
            registers.incWord(eip, 3);
          }
          break;
        case 0x61: // add [reg],reg 8
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setByte(addr, mem.getByte(addr) + registers.getByte(mem.getByte(ip + 2)));
            registers.incWord(eip, 3);
          }
          break;
        case 0x62: // add [reg],imm 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setWord(addr, mem.getWord(addr) + mem.getWord(ip + 2));
            registers.incWord(eip, 4);
          }
          break;
        case 0x63: // add [reg],imm 8
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setByte(addr, mem.getByte(addr) + mem.getByte(ip + 2));
            registers.incWord(eip, 3);
          }
          break;
        case 0x64: // add mem,reg 16
          {
            final addr = mem.getWord(ip + 1);
            mem.setWord(addr, mem.getWord(addr) + registers.getWord(mem.getByte(ip + 3)));
            registers.incWord(eip, 4);
          }
          break;
        case 0x65: // add mem,reg 8
          {
            final addr = mem.getWord(ip + 1);
            mem.setByte(addr, mem.getByte(addr) + registers.getByte(mem.getByte(ip + 3)));
            registers.incWord(eip, 4);
          }
          break;
        case 0x66: // add mem,imm 16
          {
            final addr = mem.getWord(ip + 1);
            mem.setWord(addr, mem.getWord(addr) + mem.getWord(ip + 3));
            registers.incWord(eip, 5);
          }
          break;
        case 0x67: // add mem,imm 8
          {
            final addr = mem.getWord(ip + 1);
            mem.setByte(addr, mem.getByte(addr) + mem.getByte(ip + 3));
            registers.incWord(eip, 4);
          }
          break;

        // ---- sub ----
        case 0x68: // sub reg,reg 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) - registers.getWord(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0x69: // sub reg,reg 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) - registers.getByte(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0x6A: // sub reg,imm 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) - mem.getWord(ip + 2));
          registers.incWord(eip, 4);
          break;
        case 0x6B: // sub reg,imm 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) - mem.getByte(ip + 2));
          registers.incWord(eip, 3);
          break;
        case 0x6C: // sub reg,[reg] 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) - mem.getWord(registers.getWord(mem.getByte(ip + 2))));
          registers.incWord(eip, 3);
          break;
        case 0x6D: // sub reg,[reg] 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) - mem.getByte(registers.getWord(mem.getByte(ip + 2))));
          registers.incWord(eip, 3);
          break;
        case 0x6E: // sub reg,mem 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) - mem.getWord(mem.getWord(ip + 2)));
          registers.incWord(eip, 4);
          break;
        case 0x6F: // sub reg,mem 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) - mem.getByte(mem.getWord(ip + 2)));
          registers.incWord(eip, 4);
          break;
        case 0x70: // sub [reg],reg 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setWord(addr, mem.getWord(addr) - registers.getWord(mem.getByte(ip + 2)));
            registers.incWord(eip, 3);
          }
          break;
        case 0x71: // sub [reg],reg 8
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setByte(addr, mem.getByte(addr) - registers.getByte(mem.getByte(ip + 2)));
            registers.incWord(eip, 3);
          }
          break;
        case 0x72: // sub [reg],imm 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setWord(addr, mem.getWord(addr) - mem.getWord(ip + 2));
            registers.incWord(eip, 4);
          }
          break;
        case 0x73: // sub [reg],imm 8
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setByte(addr, mem.getByte(addr) - mem.getByte(ip + 2));
            registers.incWord(eip, 3);
          }
          break;
        case 0x74: // sub mem,reg 16
          {
            final addr = mem.getWord(ip + 1);
            mem.setWord(addr, mem.getWord(addr) - registers.getWord(mem.getByte(ip + 3)));
            registers.incWord(eip, 4);
          }
          break;
        case 0x75: // sub mem,reg 8
          {
            final addr = mem.getWord(ip + 1);
            mem.setByte(addr, mem.getByte(addr) - registers.getByte(mem.getByte(ip + 3)));
            registers.incWord(eip, 4);
          }
          break;
        case 0x76: // sub mem,imm 16
          {
            final addr = mem.getWord(ip + 1);
            mem.setWord(addr, mem.getWord(addr) - mem.getWord(ip + 3));
            registers.incWord(eip, 5);
          }
          break;
        case 0x77: // sub mem,imm 8
          {
            final addr = mem.getWord(ip + 1);
            mem.setByte(addr, mem.getByte(addr) - mem.getByte(ip + 3));
            registers.incWord(eip, 4);
          }
          break;

        // ---- rol/ror ----
        case 0x78: // rol reg,reg
          {
            final n = mem.getByte(ip + 1);
            final count = registers.getWord(mem.getByte(ip + 2));
            registers.setWord(n, _rol16(registers.getWord(n), count));
            registers.incWord(eip, 3);
          }
          break;
        case 0x79: // rol reg,imm
          {
            final n = mem.getByte(ip + 1);
            final count = mem.getByte(ip + 2);
            registers.setWord(n, _rol16(registers.getWord(n), count));
            registers.incWord(eip, 3);
          }
          break;
        case 0x7A: // rol [reg],imm 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            final count = mem.getByte(ip + 2);
            mem.setWord(addr, _rol16(mem.getWord(addr), count));
            registers.incWord(eip, 3);
          }
          break;
        case 0x7B: // rol [reg],reg 8 (o C++ le a "8" mas opera em word mesmo, fiel ao original)
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            final count = registers.getWord(mem.getByte(ip + 2));
            mem.setWord(addr, _rol16(mem.getWord(addr), count));
            registers.incWord(eip, 3);
          }
          break;
        case 0x7C: // rol mem,reg
          {
            final addr = mem.getWord(ip + 1);
            final count = registers.getWord(mem.getByte(ip + 3));
            mem.setWord(addr, _rol16(mem.getWord(addr), count));
            registers.incWord(eip, 4);
          }
          break;
        case 0x7D: // rol mem,imm
          {
            final addr = mem.getWord(ip + 1);
            final count = mem.getByte(ip + 3);
            mem.setWord(addr, _rol16(mem.getWord(addr), count));
            registers.incWord(eip, 4);
          }
          break;
        case 0x7E: // ror reg,reg
          {
            final n = mem.getByte(ip + 1);
            final count = registers.getWord(mem.getByte(ip + 2));
            registers.setWord(n, _ror16(registers.getWord(n), count));
            registers.incWord(eip, 3);
          }
          break;
        case 0x7F: // ror reg,imm
          {
            final n = mem.getByte(ip + 1);
            final count = mem.getByte(ip + 2);
            registers.setWord(n, _ror16(registers.getWord(n), count));
            registers.incWord(eip, 3);
          }
          break;
        case 0x80: // ror [reg],imm
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            final count = mem.getByte(ip + 2);
            mem.setWord(addr, _ror16(mem.getWord(addr), count));
            registers.incWord(eip, 3);
          }
          break;
        case 0x81: // ror [reg],reg
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            final count = registers.getWord(mem.getByte(ip + 2));
            mem.setWord(addr, _ror16(mem.getWord(addr), count));
            registers.incWord(eip, 3);
          }
          break;
        case 0x82: // ror mem,reg
          {
            final addr = mem.getWord(ip + 1);
            final count = registers.getWord(mem.getByte(ip + 3));
            mem.setWord(addr, _ror16(mem.getWord(addr), count));
            registers.incWord(eip, 4);
          }
          break;
        case 0x83: // ror mem,imm
          {
            final addr = mem.getWord(ip + 1);
            final count = mem.getByte(ip + 3);
            mem.setWord(addr, _ror16(mem.getWord(addr), count));
            registers.incWord(eip, 4);
          }
          break;

        // ---- imul/idiv ----
        case 0x84: // imul: DX:AX = AX * DX (com sinal)
          {
            final iresult = registers.getIWord(ax) * registers.getIWord(dx);
            registers.setIWord(ax, iresult & 0xFFFF);
            registers.setIWord(dx, iresult >> 16);
            registers.incWord(eip);
          }
          break;
        case 0x85: // idiv
          {
            final divisor = registers.getIWord(dx);
            if (divisor != 0) {
              final a = registers.getIWord(ax);
              registers.setIWord(ax, a ~/ divisor);
              registers.setIWord(dx, a.remainder(divisor));
            }
            registers.incWord(eip);
          }
          break;

        // ---- ja/jb ----
        case 0x86: // ja mem
          if ((registers.getWord(flagsReg) & aboveFlag) == aboveFlag) {
            registers.setWord(eip, mem.getWord(ip + 1));
          } else {
            registers.incWord(eip, 3);
          }
          break;
        case 0x87: // jb mem
          if ((registers.getWord(flagsReg) & belowFlag) == belowFlag) {
            registers.setWord(eip, mem.getWord(ip + 1));
          } else {
            registers.incWord(eip, 3);
          }
          break;

        // ---- trig / matematica ----
        case 0x88: // atanfunc: AX = atan2(BX,DX) convertido pra "graus de bot" (0-1023)
          {
            var t = (math.atan2(registers.getIWord(bx), registers.getIWord(dx)) * 512 / math.pi).toInt();
            t -= 256;
            if (t < 0) t += 1024;
            t = -t + 1024;
            if (t >= 1024) t -= 1024;
            registers.setWord(ax, t);
            registers.incWord(eip);
          }
          break;
        case 0x89: // sqr: AX = sqrt(AX), DX = parte decimal
          {
            final value = registers.getWord(ax);
            final root = math.sqrt(value);
            registers.setWord(ax, root.toInt());
            registers.setWord(dx, ((root - root.toInt()) * 65536).toInt());
            registers.incWord(eip);
          }
          break;

        // ---- icmp (comparacao com sinal) ----
        case 0x8A: // icmp reg,reg 16
          _setCompareFlags(registers.getIWord(mem.getByte(ip + 1)), registers.getIWord(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0x8B: // icmp reg,mem 16
          _setCompareFlags(registers.getIWord(mem.getByte(ip + 1)), mem.getIWord(mem.getWord(ip + 2)));
          registers.incWord(eip, 4);
          break;
        case 0x8C: // icmp reg,[reg] 16
          _setCompareFlags(registers.getIWord(mem.getByte(ip + 1)), mem.getIWord(registers.getWord(mem.getByte(ip + 2))));
          registers.incWord(eip, 3);
          break;
        case 0x8D: // icmp reg,imm 16
          _setCompareFlags(registers.getIWord(mem.getByte(ip + 1)), mem.getIWord(ip + 2));
          registers.incWord(eip, 4);
          break;
        case 0x8E: // icmp [reg],imm 16
          _setCompareFlags(mem.getIWord(registers.getWord(mem.getByte(ip + 1))), mem.getIWord(ip + 2));
          registers.incWord(eip, 4);
          break;
        case 0x8F: // icmp mem,imm 16
          _setCompareFlags(mem.getIWord(mem.getWord(ip + 1)), mem.getIWord(ip + 3));
          registers.incWord(eip, 5);
          break;

        // ---- msg/err ----
        case 0x90: // msg reg -- le 20 bytes a partir do endereco no reg e manda como mensagem
          {
            final start = registers.getWord(mem.getByte(ip + 1));
            sendMsg(_readCString(start));
            registers.incWord(eip, 2);
          }
          break;
        case 0x91: // msg mem
          {
            final start = mem.getWord(ip + 1);
            sendMsg(_readCString(start));
            registers.incWord(eip, 3);
          }
          break;
        case 0x92: // err imm -- manda "ERROR #: <digito>"
          {
            final code = mem.getByte(ip + 1);
            sendMsg('ERROR #: ${String.fromCharCode(0x30 + code)}');
            registers.incWord(eip, 2);
          }
          break;

        // ---- arquivo do bot ----
        case 0x93: // readfile: AX=start, CX=length, DI=endereco -> AX=bytes lidos ou -1
          registers.setIWord(ax, readFile(registers.getWord(ax), registers.getWord(cx), registers.getWord(di)));
          registers.incWord(eip);
          break;
        case 0x94: // writefile: AX=start, CX=length, SI=endereco -> AX=bytes escritos ou -1
          registers.setIWord(ax, writeFile(registers.getWord(ax), registers.getWord(cx), registers.getWord(si)));
          registers.incWord(eip);
          break;

        // ---- lz/lnz/la (seta reg pra 0/1 conforme flag) ----
        case 0x95: // lz reg
          registers.setWord(
            mem.getByte(ip + 1),
            (registers.getWord(flagsReg) & equalFlag) == equalFlag ? 1 : 0,
          );
          registers.incWord(eip, 2);
          break;
        case 0x96: // lnz reg
          registers.setWord(
            mem.getByte(ip + 1),
            (registers.getWord(flagsReg) & equalFlag) != equalFlag ? 1 : 0,
          );
          registers.incWord(eip, 2);
          break;
        case 0x97: // la reg
          registers.setWord(
            mem.getByte(ip + 1),
            (registers.getWord(flagsReg) & aboveFlag) == aboveFlag ? 1 : 0,
          );
          registers.incWord(eip, 2);
          break;

        // ---- and ----
        case 0x98: // and reg,reg 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) & registers.getWord(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0x99: // and reg,reg 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) & registers.getByte(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0x9A: // and reg,imm 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) & mem.getWord(ip + 2));
          registers.incWord(eip, 4);
          break;
        case 0x9B: // and reg,imm 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) & mem.getByte(ip + 2));
          registers.incWord(eip, 3);
          break;
        case 0x9C: // and reg,[reg] 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) & mem.getWord(registers.getWord(mem.getByte(ip + 2))));
          registers.incWord(eip, 3);
          break;
        case 0x9D: // and reg,[reg] 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) & mem.getByte(registers.getWord(mem.getByte(ip + 2))));
          registers.incWord(eip, 3);
          break;
        case 0x9E: // and reg,mem 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) & mem.getWord(mem.getWord(ip + 2)));
          registers.incWord(eip, 4);
          break;
        case 0x9F: // and reg,mem 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) & mem.getByte(mem.getWord(ip + 2)));
          registers.incWord(eip, 4);
          break;
        case 0xA0: // and [reg],reg 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setWord(addr, mem.getWord(addr) & registers.getWord(mem.getByte(ip + 2)));
            registers.incWord(eip, 3);
          }
          break;
        case 0xA1: // and [reg],reg 8
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setByte(addr, mem.getByte(addr) & registers.getByte(mem.getByte(ip + 2)));
            registers.incWord(eip, 3);
          }
          break;
        case 0xA2: // and [reg],imm 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setWord(addr, mem.getWord(addr) & mem.getWord(ip + 2));
            registers.incWord(eip, 4);
          }
          break;
        case 0xA3: // and [reg],imm 8
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setByte(addr, mem.getByte(addr) & mem.getByte(ip + 2));
            registers.incWord(eip, 3);
          }
          break;
        case 0xA4: // and mem,reg 16
          {
            final addr = mem.getWord(ip + 1);
            mem.setWord(addr, mem.getWord(addr) & registers.getWord(mem.getByte(ip + 3)));
            registers.incWord(eip, 4);
          }
          break;
        case 0xA5: // and mem,reg 8
          {
            final addr = mem.getWord(ip + 1);
            mem.setByte(addr, mem.getByte(addr) & registers.getByte(mem.getByte(ip + 3)));
            registers.incWord(eip, 4);
          }
          break;
        case 0xA6: // and mem,imm 16
          {
            final addr = mem.getWord(ip + 1);
            mem.setWord(addr, mem.getWord(addr) & mem.getWord(ip + 3));
            registers.incWord(eip, 5);
          }
          break;
        case 0xA7: // and mem,imm 8
          {
            final addr = mem.getWord(ip + 1);
            mem.setByte(addr, mem.getByte(addr) & mem.getByte(ip + 3));
            registers.incWord(eip, 4);
          }
          break;

        // ---- or ----
        case 0xA8: // or reg,reg 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) | registers.getWord(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0xA9: // or reg,reg 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) | registers.getByte(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0xAA: // or reg,imm 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) | mem.getWord(ip + 2));
          registers.incWord(eip, 4);
          break;
        case 0xAB: // or reg,imm 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) | mem.getByte(ip + 2));
          registers.incWord(eip, 3);
          break;
        case 0xAC: // or reg,[reg] 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) | mem.getWord(registers.getWord(mem.getByte(ip + 2))));
          registers.incWord(eip, 3);
          break;
        case 0xAD: // or reg,[reg] 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) | mem.getByte(registers.getWord(mem.getByte(ip + 2))));
          registers.incWord(eip, 3);
          break;
        case 0xAE: // or reg,mem 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) | mem.getWord(mem.getWord(ip + 2)));
          registers.incWord(eip, 4);
          break;
        case 0xAF: // or reg,mem 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) | mem.getByte(mem.getWord(ip + 2)));
          registers.incWord(eip, 4);
          break;
        case 0xB0: // or [reg],reg 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setWord(addr, mem.getWord(addr) | registers.getWord(mem.getByte(ip + 2)));
            registers.incWord(eip, 3);
          }
          break;
        case 0xB1: // or [reg],reg 8
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setByte(addr, mem.getByte(addr) | registers.getByte(mem.getByte(ip + 2)));
            registers.incWord(eip, 3);
          }
          break;
        case 0xB2: // or [reg],imm 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setWord(addr, mem.getWord(addr) | mem.getWord(ip + 2));
            registers.incWord(eip, 4);
          }
          break;
        case 0xB3: // or [reg],imm 8
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setByte(addr, mem.getByte(addr) | mem.getByte(ip + 2));
            registers.incWord(eip, 3);
          }
          break;
        case 0xB4: // or mem,reg 16
          {
            final addr = mem.getWord(ip + 1);
            mem.setWord(addr, mem.getWord(addr) | registers.getWord(mem.getByte(ip + 3)));
            registers.incWord(eip, 4);
          }
          break;
        case 0xB5: // or mem,reg 8
          {
            final addr = mem.getWord(ip + 1);
            mem.setByte(addr, mem.getByte(addr) | registers.getByte(mem.getByte(ip + 3)));
            registers.incWord(eip, 4);
          }
          break;
        case 0xB6: // or mem,imm 16
          {
            final addr = mem.getWord(ip + 1);
            mem.setWord(addr, mem.getWord(addr) | mem.getWord(ip + 3));
            registers.incWord(eip, 5);
          }
          break;
        case 0xB7: // or mem,imm 8
          {
            final addr = mem.getWord(ip + 1);
            mem.setByte(addr, mem.getByte(addr) | mem.getByte(ip + 3));
            registers.incWord(eip, 4);
          }
          break;

        // ---- xor ----
        case 0xB8: // xor reg,reg 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) ^ registers.getWord(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0xB9: // xor reg,reg 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) ^ registers.getByte(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0xBA: // xor reg,imm 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) ^ mem.getWord(ip + 2));
          registers.incWord(eip, 4);
          break;
        case 0xBB: // xor reg,imm 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) ^ mem.getByte(ip + 2));
          registers.incWord(eip, 3);
          break;
        case 0xBC: // xor reg,[reg] 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) ^ mem.getWord(registers.getWord(mem.getByte(ip + 2))));
          registers.incWord(eip, 3);
          break;
        case 0xBD: // xor reg,[reg] 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) ^ mem.getByte(registers.getWord(mem.getByte(ip + 2))));
          registers.incWord(eip, 3);
          break;
        case 0xBE: // xor reg,mem 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) ^ mem.getWord(mem.getWord(ip + 2)));
          registers.incWord(eip, 4);
          break;
        case 0xBF: // xor reg,mem 8
          registers.setByte(mem.getByte(ip + 1), registers.getByte(mem.getByte(ip + 1)) ^ mem.getByte(mem.getWord(ip + 2)));
          registers.incWord(eip, 4);
          break;
        case 0xC0: // xor [reg],reg 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setWord(addr, mem.getWord(addr) ^ registers.getWord(mem.getByte(ip + 2)));
            registers.incWord(eip, 3);
          }
          break;
        case 0xC1: // xor [reg],reg 8
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setByte(addr, mem.getByte(addr) ^ registers.getByte(mem.getByte(ip + 2)));
            registers.incWord(eip, 3);
          }
          break;
        case 0xC2: // xor [reg],imm 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setWord(addr, mem.getWord(addr) ^ mem.getWord(ip + 2));
            registers.incWord(eip, 4);
          }
          break;
        case 0xC3: // xor [reg],imm 8
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setByte(addr, mem.getByte(addr) ^ mem.getByte(ip + 2));
            registers.incWord(eip, 3);
          }
          break;
        case 0xC4: // xor mem,reg 16
          {
            final addr = mem.getWord(ip + 1);
            mem.setWord(addr, mem.getWord(addr) ^ registers.getWord(mem.getByte(ip + 3)));
            registers.incWord(eip, 4);
          }
          break;
        case 0xC5: // xor mem,reg 8
          {
            final addr = mem.getWord(ip + 1);
            mem.setByte(addr, mem.getByte(addr) ^ registers.getByte(mem.getByte(ip + 3)));
            registers.incWord(eip, 4);
          }
          break;
        case 0xC6: // xor mem,imm 16
          {
            final addr = mem.getWord(ip + 1);
            mem.setWord(addr, mem.getWord(addr) ^ mem.getWord(ip + 3));
            registers.incWord(eip, 5);
          }
          break;
        case 0xC7: // xor mem,imm 8
          {
            final addr = mem.getWord(ip + 1);
            mem.setByte(addr, mem.getByte(addr) ^ mem.getByte(ip + 3));
            registers.incWord(eip, 4);
          }
          break;

        // ---- shl/shr (logico, sem sinal) ----
        case 0xC8: // shl reg,imm 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) << mem.getByte(ip + 2));
          registers.incWord(eip, 3);
          break;
        case 0xC9: // shl reg,reg 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) << registers.getWord(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0xCA: // shl [reg],imm 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setWord(addr, mem.getWord(addr) << mem.getByte(ip + 2));
            registers.incWord(eip, 3);
          }
          break;
        case 0xCB: // shl [reg],reg 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setWord(addr, mem.getWord(addr) << registers.getWord(mem.getByte(ip + 2)));
            registers.incWord(eip, 3);
          }
          break;
        case 0xCC: // shl mem,imm 16
          {
            final addr = mem.getWord(ip + 1);
            mem.setWord(addr, mem.getWord(addr) << mem.getByte(ip + 3));
            registers.incWord(eip, 4);
          }
          break;
        case 0xCD: // shl mem,reg 16
          {
            final addr = mem.getWord(ip + 1);
            mem.setWord(addr, mem.getWord(addr) << registers.getWord(mem.getByte(ip + 3)));
            registers.incWord(eip, 4);
          }
          break;
        case 0xCE: // shr reg,imm 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) >> mem.getByte(ip + 2));
          registers.incWord(eip, 3);
          break;
        case 0xCF: // shr reg,reg 16
          registers.setWord(mem.getByte(ip + 1), registers.getWord(mem.getByte(ip + 1)) >> registers.getWord(mem.getByte(ip + 2)));
          registers.incWord(eip, 3);
          break;
        case 0xD0: // shr [reg],imm 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setWord(addr, mem.getWord(addr) >> mem.getByte(ip + 2));
            registers.incWord(eip, 3);
          }
          break;
        case 0xD1: // shr [reg],reg 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            mem.setWord(addr, mem.getWord(addr) >> registers.getWord(mem.getByte(ip + 2)));
            registers.incWord(eip, 3);
          }
          break;
        case 0xD2: // shr mem,imm 16
          {
            final addr = mem.getWord(ip + 1);
            mem.setWord(addr, mem.getWord(addr) >> mem.getByte(ip + 3));
            registers.incWord(eip, 4);
          }
          break;
        case 0xD3: // shr mem,reg 16
          {
            final addr = mem.getWord(ip + 1);
            mem.setWord(addr, mem.getWord(addr) >> registers.getWord(mem.getByte(ip + 3)));
            registers.incWord(eip, 4);
          }
          break;

        // ---- ishl/ishr (com sinal) ----
        // Nota: o 0xD4 original (ISHL reg,imm) tem duas atribuicoes
        // seguidas que acabam deslocando o valor DUAS vezes (a segunda
        // linha reusa o resultado da primeira) -- parece um bug do
        // jogo original, mas replicamos o comportamento de fato.
        case 0xD4: // ishl reg,imm 16 (deslocamento duplicado, fiel ao original)
          {
            final n = mem.getByte(ip + 1);
            final count = mem.getByte(ip + 2);
            var v = registers.getIWord(n) << count; // 1a atribuicao do original
            v = (v.toUnsigned(16)) << count; // 2a atribuicao (reaplica o shift)
            registers.setIWord(n, v);
            registers.incWord(eip, 3);
          }
          break;
        case 0xD5: // ishl reg,reg 16
          {
            final n = mem.getByte(ip + 1);
            final count = registers.getWord(mem.getByte(ip + 2));
            registers.setIWord(n, registers.getIWord(n) << count);
            registers.incWord(eip, 3);
          }
          break;
        case 0xD6: // ishl [reg],imm 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            final count = mem.getByte(ip + 2);
            mem.setIWord(addr, mem.getIWord(addr) << count);
            registers.incWord(eip, 3);
          }
          break;
        case 0xD7: // ishl [reg],reg 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            final count = registers.getWord(mem.getByte(ip + 2));
            mem.setIWord(addr, mem.getIWord(addr) << count);
            registers.incWord(eip, 3);
          }
          break;
        case 0xD8: // ishl mem,imm 16
          {
            final addr = mem.getWord(ip + 1);
            final count = mem.getByte(ip + 3);
            mem.setIWord(addr, mem.getIWord(addr) << count);
            registers.incWord(eip, 4);
          }
          break;
        case 0xD9: // ishl mem,reg 16
          {
            final addr = mem.getWord(ip + 1);
            final count = registers.getWord(mem.getByte(ip + 3));
            mem.setIWord(addr, mem.getIWord(addr) << count);
            registers.incWord(eip, 4);
          }
          break;
        case 0xDA: // ishr reg,imm 16
          {
            final n = mem.getByte(ip + 1);
            final count = mem.getByte(ip + 2);
            registers.setIWord(n, registers.getIWord(n) >> count);
            registers.incWord(eip, 3);
          }
          break;
        case 0xDB: // ishr reg,reg 16
          {
            final n = mem.getByte(ip + 1);
            final count = registers.getWord(mem.getByte(ip + 2));
            registers.setIWord(n, registers.getIWord(n) >> count);
            registers.incWord(eip, 3);
          }
          break;
        case 0xDC: // ishr [reg],imm 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            final count = mem.getByte(ip + 2);
            mem.setIWord(addr, mem.getIWord(addr) >> count);
            registers.incWord(eip, 3);
          }
          break;
        case 0xDD: // ishr [reg],reg 16
          {
            final addr = registers.getWord(mem.getByte(ip + 1));
            final count = registers.getWord(mem.getByte(ip + 2));
            mem.setIWord(addr, mem.getIWord(addr) >> count);
            registers.incWord(eip, 3);
          }
          break;
        case 0xDE: // ishr mem,imm 16
          {
            final addr = mem.getWord(ip + 1);
            final count = mem.getByte(ip + 3);
            mem.setIWord(addr, mem.getIWord(addr) >> count);
            registers.incWord(eip, 4);
          }
          break;
        case 0xDF: // ishr mem,reg 16
          {
            final addr = mem.getWord(ip + 1);
            final count = registers.getWord(mem.getByte(ip + 3));
            mem.setIWord(addr, mem.getIWord(addr) >> count);
            registers.incWord(eip, 4);
          }
          break;

        // ---- interrupt / mul / div / ret imm ----
        case 0xE0: // int imm
          {
            mem.setWord(registers.getWord(sp), ip + 2);
            final tt = mem.returnSize();
            final argum = mem.getByte(ip + 1);
            registers.setWord(eip, mem.getWord(tt - (argum * 2 + 2)));
            registers.incWord(sp, 2);
            registers.setWord(flagsReg, registers.getWord(flagsReg) & 0xFBFF);
          }
          break;
        case 0xE1: // mul: DX:AX = AX * DX (sem sinal)
          {
            final result = registers.getWord(ax) * registers.getWord(dx);
            registers.setWord(ax, result & 0xFFFF);
            registers.setWord(dx, result >> 16);
            registers.incWord(eip);
          }
          break;
        case 0xE2: // div
          {
            final divisor = registers.getWord(dx);
            if (divisor != 0) {
              final a = registers.getWord(ax);
              registers.setWord(ax, a ~/ divisor);
              registers.setWord(dx, a % divisor);
            }
            registers.incWord(eip);
          }
          break;
        case 0xE3: // ret imm -- desempilha o endereco de retorno e ainda "encolhe" a pilha em `imm` bytes extra
          {
            final extra = mem.getByte(ip + 1);
            registers.decWord(sp, 2);
            registers.setWord(eip, mem.getWord(registers.getWord(sp)));
            registers.decWord(sp, extra);
          }
          break;

        // ---- lodsb/lodsw ----
        case 0xE4: // lodsb
          registers.setByte(al, mem.getByte(registers.getWord(si)));
          registers.incWord(si);
          registers.incWord(eip);
          break;
        case 0xE5: // lodsw
          registers.setWord(ax, mem.getWord(registers.getWord(si)));
          registers.incWord(si, 2);
          registers.incWord(eip);
          break;

        // ---- funcoes trigonometricas ----
        case 0xE6: // sinfunc: AX = AX + BX * sin(DX em "graus de bot")
          {
            final v = registers.getWord(ax) + registers.getWord(bx) * math.sin(registers.getWord(dx) / 512.0 * 3.1416);
            registers.setWord(ax, v.toInt());
            registers.incWord(eip);
          }
          break;
        case 0xE7: // cosfunc: AX = AX + BX * cos(DX)
          {
            final v = registers.getWord(ax) + registers.getWord(bx) * math.cos(registers.getWord(dx) / 512.0 * 3.1416);
            registers.setWord(ax, v.toInt());
            registers.incWord(eip);
          }
          break;
        case 0xE8: // sin: AX = sin(AX)
          registers.setIWord(ax, (math.sin(registers.getWord(ax) / 512.0 * 3.1416) * 32768).toInt());
          registers.incWord(eip);
          break;
        case 0xE9: // cos: AX = cos(AX)
          registers.setIWord(ax, (math.cos(registers.getWord(ax) / 512.0 * 3.1416) * 32768).toInt());
          registers.incWord(eip);
          break;

        // ---- mov reg,[reg+val] / mov [reg+val],reg ----
        case 0xEA: // mov reg,[reg+val]
          registers.setWord(
            mem.getByte(ip + 1),
            mem.getWord(registers.getWord(mem.getByte(ip + 2)) + mem.getByte(ip + 3)),
          );
          registers.incWord(eip, 4);
          break;
        case 0xEB: // mov [reg+val],reg
          mem.setWord(
            registers.getWord(mem.getByte(ip + 1)) + mem.getByte(ip + 2),
            registers.getWord(mem.getByte(ip + 3)),
          );
          registers.incWord(eip, 4);
          break;

        // ---- rnd/hwait ----
        case 0xEC: // rnd: AX = numero aleatorio de 16 bits
          registers.setWord(ax, _random.nextInt(0x10000));
          registers.incWord(eip);
          break;
        case 0xED: // hwait: encerra o resto do ciclo de execucao atual
          registers.incWord(eip);
          if (cyclesLeft > 0) {
            cyclesLeft = 0;
          }
          break;

        // ---- lb/lae/lbe (seta reg pra 0/1 conforme flag) ----
        case 0xEE: // lb reg
          registers.setWord(
            mem.getByte(ip + 1),
            (registers.getWord(flagsReg) & belowFlag) == belowFlag ? 1 : 0,
          );
          registers.incWord(eip, 2);
          break;
        case 0xEF: // lae/lnb reg
          registers.setWord(
            mem.getByte(ip + 1),
            (registers.getWord(flagsReg) & belowFlag) != belowFlag ? 1 : 0,
          );
          registers.incWord(eip, 2);
          break;
        case 0xF0: // lbe/lna reg
          registers.setWord(
            mem.getByte(ip + 1),
            (registers.getWord(flagsReg) & aboveFlag) != aboveFlag ? 1 : 0,
          );
          registers.incWord(eip, 2);
          break;

        // ---- cj/cjn (salto condicional por valor de registrador) ----
        case 0xF1: // cj reg,label
          if (registers.getWord(mem.getByte(ip + 1)) >= 1) {
            registers.setWord(eip, mem.getWord(ip + 2));
          } else {
            registers.incWord(eip, 4);
          }
          break;
        case 0xF2: // cjn reg,label
          if (registers.getWord(mem.getByte(ip + 1)) == 0) {
            registers.setWord(eip, mem.getWord(ip + 2));
          } else {
            registers.incWord(eip, 4);
          }
          break;

        default:
          // Opcode desconhecido (era o `default` do switch original):
          // avanca 1 byte e ainda consome 1 ciclo, pra garantir que o
          // loop sempre progride mesmo topando com bytecode invalido.
          registers.incWord(eip);
          cyclesLeft--;
      }

      if (singleStepMode) {
        cyclesLeft = 0;
      }
    }
  }

  /// Era o bloco repetido em TEST (0x29-0x2E): testa o bit `bit` de
  /// `value` e seta/limpa a flag de igualdade.
  void _testBit(int value, int bit) {
    if (bit <= 15) {
      var test = value & 0xFFFF;
      test = (test << (15 - bit)) & 0xFFFF;
      test = test >> 15;
      if (test == 1) {
        registers.setWord(flagsReg, registers.getWord(flagsReg) | setEqualFlag);
      } else {
        registers.setWord(flagsReg, registers.getWord(flagsReg) & setUnequalFlag);
      }
    }
  }

  /// Rotaciona `value` (word de 16 bits) `count` posicoes pra
  /// esquerda, bit a bit, exatamente como o loop `for` do ROL
  /// original (0x78-0x7D).
  int _rol16(int value, int count) {
    var v = value & 0xFFFF;
    for (var x = 0; x < count; x++) {
      if ((v & 0x8000) == 0x8000) {
        v = ((v << 1) + 1) & 0xFFFF;
      } else {
        v = (v << 1) & 0xFFFF;
      }
    }
    return v;
  }

  /// Rotaciona `value` `count` posicoes pra direita (ROR, 0x7E-0x83).
  int _ror16(int value, int count) {
    var v = value & 0xFFFF;
    for (var x = 0; x < count; x++) {
      if ((v & 1) == 1) {
        v = (v >> 1) + 0x8000;
      } else {
        v = v >> 1;
      }
    }
    return v;
  }

  /// Le uma "string" de ate 20 bytes a partir de `address` na RAM,
  /// parando no primeiro byte nulo -- era o buffer `char message[20]`
  /// preenchido por MSG (0x90/0x91) antes de `sendmsg`.
  String _readCString(int address) {
    final bytes = <int>[];
    for (var x = 0; x < 20; x++) {
      final b = mem.getByte(address + x);
      if (b == 0) break;
      bytes.add(b);
    }
    return String.fromCharCodes(bytes);
  }

  /// Era o bloco repetido em CMP (0x2F-0x3A): seta above/below/equal
  /// de acordo com a comparacao de dois valores.
  void _setCompareFlags(int a, int b) {
    var f = registers.getWord(flagsReg);
    if (a == b) {
      f = (f | setEqualFlag) & clearEqualFlags;
    }
    if (a > b) {
      f = (f | setAboveFlag) & clearAboveFlags;
    }
    if (a < b) {
      f = (f | setBelowFlag) & clearBelowFlags;
    }
    registers.setWord(flagsReg, f);
  }
}
