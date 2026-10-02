import 'dart:math' as math;

import '../core/device.dart';
import '../core/screen_object.dart';

// Porte de src/scanner.h e src/scanner.cpp (droidbattles original) --
// radar: ao receber pulso na porta 0, procura o objeto mais proximo
// dentro do arco de varredura, guarda distancia/angulo/id/freq/dir/
// velocidade e avisa o bot escaneado.
//
// Fica de fora (so UI, Qt): `erase`/`draw` (desenho do arco verde).
// `scanShow` e mantido pra quando a camada de UI existir.
//
// Diferencas conhecidas do C++: `wret`, `lastscanfreq`, `lastscanid`,
// `lastscandir`, `lastscanspeed` ficavam SEM inicializar no
// construtor (lixo de memoria); aqui comecam em 0. Alem disso, a
// distancia usa ints de 64 bits (sem o overflow de 32 bits que o C++
// teria nos cantos extremos de uma arena de 32768x32768).
class Scanner extends Device {
  Scanner(ScreenObject object, int arg1, int offset) : super(object) {
    ourlevel = arg1;
    maxScanDist = ourlevel;
    relang = offset * 4;
  }

  int threshold = 5;
  int scanShow = 0;
  int width = 128;
  int maxScanDist = 0;
  int lastScanDist = 65535;
  int lastScanAng = 2;
  int wRet = 0;
  int lastScanFreq = 0;
  int lastScanId = 0;
  int lastScanDir = 0;
  int lastScanSpeed = 0;

  @override
  void execute() {
    // Pulso de scan: procura o objeto visivel mais proximo no arco.
    if (stackTaken[0][0]) {
      movePortStack(0);

      scanShow = 1;
      lastScanDist = 65535;
      lastScanAng = 2;
      for (var count = 0; count < 255; count++) {
        if (count != ourbot!.number() &&
            ourbot!.writeToBattleArea(0, 0, 6, count, 0) >= threshold) {
          final ourX = ourbot!.xPos();
          final ourY = ourbot!.yPos();
          final hisX = ourbot!.writeToBattleArea(0, 0, 1, count, 0);
          final hisY = ourbot!.writeToBattleArea(0, 0, 2, count, 0);

          var mangle = ourbot!.direction() + relang;
          if (mangle >= 1024) mangle -= 1024;

          final distX = ourX - hisX;
          final distY = ourY - hisY;
          final dist = math.sqrt((distX * distX + distY * distY).toDouble()).toInt();

          var angle = (math.atan2(distY.toDouble(), distX.toDouble()) * 512 / math.pi).toInt();
          angle -= 512;
          if (angle >= 1024) angle -= 1024;
          if (angle < 0) angle += 1024;

          int leftAng, rightAng;
          if (mangle > angle) {
            leftAng = mangle - angle;
            rightAng = angle + 1024 - mangle;
          } else {
            leftAng = mangle + 1024 - angle;
            rightAng = angle - mangle;
          }

          if ((leftAng < width || rightAng < width) &&
              dist.abs() < lastScanDist &&
              dist.abs() < maxScanDist) {
            lastScanDist = dist;
            final double widthInArc;
            if (leftAng < width) {
              widthInArc = (width - leftAng).toDouble();
            } else {
              widthInArc = (width + rightAng).toDouble();
            }

            // (width*2)~/5 vira 0 se width < 3 -- no C++ seria divisao por
            // zero (comportamento indefinido); em Dart .toInt() de
            // Infinity lancaria excecao, entao travamos o divisor em 1.
            final arcDivisor = math.max(1, (width * 2) ~/ 5);
            lastScanAng = (widthInArc / arcDivisor).toInt();
            lastScanId = count;
            lastScanFreq = ourbot!.writeToBattleArea(0, 0, 8, count, 0);
            lastScanDir = ourbot!.writeToBattleArea(0, 0, 3, count, 0);
            lastScanSpeed = ourbot!.writeToBattleArea(0, 0, 4, count, 0);
            if (lastScanAng == 5) lastScanAng--;

            // Avisa o bot escaneado (intensidade + direcao de onde veio).
            var tdir = lastScanAng - 2;
            if (tdir < 0) tdir = -tdir;
            final tdist = (lastScanDist / maxScanDist * 4).toInt();
            final tint = tdir + tdist;
            tdir = (angle >> 7) << 7;
            tdir += 512;
            if (tdir >= 1024) tdir -= 1024;
            ourbot!.writeToBattleArea(count, 0, 9, tint, tdir);
          }
        }
      }
    }
    // Largura do arco.
    if (stackTaken[1][0]) {
      width = portStack[1][0];
      movePortStack(1);
    }
    // Seleciona o retorno da porta 3.
    if (stackTaken[2][0]) {
      wRet = portStack[2][0];
      movePortStack(2);
    }
    // Sensibilidade.
    if (stackTaken[3][0]) {
      threshold = portStack[3][0];
      movePortStack(3);
    }
  }

  @override
  int readPort(int port) {
    switch (port) {
      case 0:
        return lastScanDist;
      case 1:
        return lastScanAng;
      case 2:
        return width;
      case 3:
        if (wRet == 0) return lastScanFreq;
        if (wRet == 1) return lastScanId;
        if (wRet == 2) return lastScanDir;
        if (wRet == 3) return lastScanSpeed;
        break;
    }
    return 0;
  }
}
