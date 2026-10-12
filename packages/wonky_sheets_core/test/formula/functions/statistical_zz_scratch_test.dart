import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';

void main() {
  test('scratch', () {
    final t = FormulaTestBench();
    for (final f in [
      '=T.INV(0.9999999,1)', '=T.INV(0.999999,3)', '=CHISQ.INV(0.999,1000)', '=F.INV(0.5,1000,1000)', '=BETA.INV(0.001,0.5,0.5)',
      '=GAMMA.INV(0.99,0.1,1)', '=GAMMA.INV(1E-10,0.1,1)', '=NORM.S.DIST(-38)', '=BINOM.DIST(5000,10000,0.5,TRUE)',
      '=POISSON.DIST(1000,1000,TRUE)', '=GAMMA(171.5)', '=GAMMA(-0.5)', '=GAMMA(170.5)', '=T.DIST(1,1E9,TRUE)',
      '=CHISQ.DIST.RT(1E5,3)', '=BINOM.INV(1000000,0.3,0.5)', '=CHISQ.INV.RT(1E-12,1)', '=T.INV.2T(1E-12,2)',
      '=NORM.S.INV(1E-300)', '=F.INV.RT(1E-10,1,1)', '=BETA.INV(0.5,1000,1000)', '=GAMMALN(1E300)', '=T.DIST(0,1,FALSE)',
      '=CHISQ.DIST(0,2,FALSE)', '=CHISQ.DIST(0,1,FALSE)', '=F.DIST(0,1,1,FALSE)', '=NEGBINOM.DIST(5000,10,0.001,TRUE)',
      '=HYPGEOM.DIST(500,1000,5000,10000,TRUE)', '=T.INV(0.75,1E9)', '=GAMMA.DIST(1E6,1E6,1,TRUE)',
    ]) {
      final sw = Stopwatch()..start();
      final v = t.eval(f);
      print('$f -> $v (${sw.elapsedMicroseconds}us)');
    }
  });
}
