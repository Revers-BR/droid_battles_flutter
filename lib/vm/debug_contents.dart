// Porte de src/debugcontents.h (droidbattles original) -- um
// "retrato" dos registradores e de um pedaco da memoria ao redor de
// alguns deles, num instante da simulacao. Usado pelo depurador.
class DebugContents {
  const DebugContents({
    required this.flags,
    required this.ax,
    required this.bx,
    required this.cx,
    required this.dx,
    required this.sp,
    required this.si,
    required this.di,
    required this.bp,
    required this.ip,
    required this.ipContents,
    required this.spContents,
    required this.siContents,
    required this.diContents,
    required this.execMem,
  });

  final int flags, ax, bx, cx, dx, sp, si, di, bp, ip;

  /// 9 bytes ao redor do endereco (posicao -4..+4), igual ao original.
  final List<int> ipContents;
  final List<int> spContents;
  final List<int> siContents;
  final List<int> diContents;

  /// Ultimos ate 30 enderecos executados (era `RobCpu::lastexecmem`).
  final List<int> execMem;
}
