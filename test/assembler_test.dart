import 'package:droid_battles/assembler/assembler.dart';
import 'package:droid_battles/vm/ram.dart';
import 'package:flutter_test/flutter_test.dart';

// Mais testes de fumaca escritos SEM poder rodar (mesma ressalva do
// vm_test.dart). Rode com `flutter test`.

void main() {
  test('monta mov ax,5 / add ax,3 e resolve label pra frente', () {
    final devices = List.generate(32, (i) => i == 0 ? const DeviceSlot(type: 1, level: 0) : const DeviceSlot());
    final result = Assembler.assemble(
      source: '''
%CPUboot 0
mov ax,5
jmp fim
mov ax,999
:fim
add ax,3
''',
      ramSizeIndex: 0,
      devices: devices,
    );
    expect(result.success, isTrue, reason: result.error?.toString());
    // mem[4]/mem[5] = bootMemLow/High do device 0 -- deve apontar pro
    // "mov ax,5" (posInMem 0, ja que %CPUboot foi a 1a linha "real").
    expect(result.mem![4], 0);
    expect(result.mem![5], 0);
  });

  test('erro em símbolo não declarado', () {
    final devices = List.generate(32, (_) => const DeviceSlot());
    final result = Assembler.assemble(
      source: 'jmp naoexiste\n',
      ramSizeIndex: 0,
      devices: devices,
    );
    expect(result.success, isFalse);
  });

  test('Ram.sizeOptions[0] == 1024', () {
    expect(Ram.sizeOptions[0], 1024);
  });
}
