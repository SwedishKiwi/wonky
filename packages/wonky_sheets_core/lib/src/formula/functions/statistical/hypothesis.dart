import 'dart:math' as math;

import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../helpers.dart';
import '../registry.dart';
import 'common.dart';
import 'special.dart';

/// Hypothesis tests (Z/T/F/χ²) and MARGINOFERROR (05 §15.2).
void registerHypothesisTests(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.statistical;
  b.fn(
    'Z.TEST',
    'Returns the one-tailed P-value of a Z-test with standard distribution.',
    [
      P.range('data', 'The sample of data to test.'),
      P.num('value', 'The test statistic to use in the Z-test.'),
      P.num(
        'standard_deviation',
        'The standard deviation to assume for the Z-test. If omitted, the standard deviation of data is used.',
        true,
      ),
    ],
    (a) {
      final xs = a.numbers(from: 0, to: 1);
      final x = a.number(1);
      if (xs.isEmpty) fail(ErrorKind.na);
      final n = xs.length;
      final s = a.has(2)
          ? a.number(2)
          : math.sqrt(variance(a, xs, sample: true));
      if (s <= 0) divZero(a);
      final z = (meanOf(xs) - x) / (s / math.sqrt(n));
      return stableResult(Special.normCdf(-z));
    },
    aliases: ['ZTEST'],
    priority: Priority.p2,
    examples: ['Z.TEST(A2:A100, B2)'],
    seeAlso: ['T.TEST', 'CONFIDENCE.NORM'],
  );
  b.fn(
    'T.TEST',
    'Returns the probability associated with Student\'s t-test. Determines whether two samples are likely to have come from the same two underlying populations that have the same mean.',
    [
      P.array(
        'range1',
        'The first sample of data or group of cells to consider for the t-test.',
      ),
      P.array(
        'range2',
        'The second sample of data or group of cells to consider for the t-test.',
      ),
      P.num('tails', 'Specifies the number of distribution tails (1 or 2).'),
      P.num(
        'type',
        'Specifies the type of t-test: 1 paired, 2 two-sample equal variance, 3 two-sample unequal variance.',
      ),
    ],
    (a) {
      final tails = a.integer(2), type = a.integer(3);
      if ((tails != 1 && tails != 2) || type < 1 || type > 3) {
        fail(ErrorKind.num);
      }
      double t, df;
      if (type == 1) {
        final (ys, xs) = pairedNumbers(a, 0, 1);
        final n = ys.length;
        if (n < 2) divZero(a);
        final d = [for (var k = 0; k < n; k++) ys[k] - xs[k]];
        final sd = math.sqrt(devSq(d) / (n - 1));
        if (sd == 0) divZero(a);
        t = meanOf(d) / (sd / math.sqrt(n));
        df = n - 1.0;
      } else {
        final x1 = a.numbers(from: 0, to: 1), x2 = a.numbers(from: 1, to: 2);
        final n1 = x1.length.toDouble(), n2 = x2.length.toDouble();
        if (n1 < 2 || n2 < 2) divZero(a);
        final v1 = devSq(x1) / (n1 - 1), v2 = devSq(x2) / (n2 - 1);
        final diff = meanOf(x1) - meanOf(x2);
        if (type == 2) {
          df = n1 + n2 - 2;
          final sp = ((n1 - 1) * v1 + (n2 - 1) * v2) / df;
          final den = math.sqrt(sp * (1 / n1 + 1 / n2));
          if (den == 0) divZero(a);
          t = diff / den;
        } else {
          final q1 = v1 / n1, q2 = v2 / n2;
          final den = math.sqrt(q1 + q2);
          if (den == 0) divZero(a);
          t = diff / den;
          df =
              (q1 + q2) * (q1 + q2) / (q1 * q1 / (n1 - 1) + q2 * q2 / (n2 - 1));
        }
      }
      return stableResult(tails * Special.tSf(t.abs(), df));
    },
    aliases: ['TTEST'],
    examples: ['T.TEST(A1:A4, B1:B4, 2, 1)'],
    seeAlso: ['Z.TEST', 'F.TEST', 'T.DIST'],
  );
  b.fn(
    'F.TEST',
    'Returns the probability associated with an F-test for equality of variances. Determines whether two samples are likely to have come from populations with the same variance.',
    [
      P.array(
        'range1',
        'The first sample of data or group of cells to consider for the F-test.',
      ),
      P.array(
        'range2',
        'The second sample of data or group of cells to consider for the F-test.',
      ),
    ],
    (a) {
      final x1 = a.numbers(from: 0, to: 1), x2 = a.numbers(from: 1, to: 2);
      if (x1.length < 2 || x2.length < 2) divZero(a);
      final v1 = devSq(x1) / (x1.length - 1), v2 = devSq(x2) / (x2.length - 1);
      if (v1 == 0 || v2 == 0) divZero(a);
      final f = v1 / v2;
      final d1 = x1.length - 1.0, d2 = x2.length - 1.0;
      final p = 2.0 * math.min(Special.fCdf(f, d1, d2), Special.fSf(f, d1, d2));
      return stableResult(math.min(p, 1.0));
    },
    aliases: ['FTEST'],
    examples: ['F.TEST(A1:A4, B1:B4)'],
    seeAlso: ['T.TEST', 'F.DIST'],
  );
  b.fn(
    'CHISQ.TEST',
    'Returns the probability associated with a Pearson\'s chi-squared test on the two ranges of data. Determines the likelihood that the observed categorical data is drawn from an expected distribution.',
    [
      P.array(
        'observed_range',
        'The observed number of each combination of factors.',
      ),
      P.array(
        'expected_range',
        'The expected number of each combination of factors.',
      ),
    ],
    (a) {
      final o = a.array(0), e = a.array(1);
      if (o.rows != e.rows || o.cols != e.cols) {
        fail(ErrorKind.na, ErrorMessages.arraySizeMismatch(a.fn));
      }
      if (o.length < 2) fail(ErrorKind.na);
      var chi = 0.0;
      for (var k = 0; k < o.length; k++) {
        var ov = o.atIndex(k), ev = e.atIndex(k);
        if (ov is FRich) ov = ov.scalar;
        if (ev is FRich) ev = ev.scalar;
        if (ov is FError) throw FormulaError(ov);
        if (ev is FError) throw FormulaError(ev);
        if (ov is! FNumber || ev is! FNumber) continue;
        if (ev.v < 0) fail(ErrorKind.num);
        if (ev.v == 0) divZero(a);
        chi += (ov.v - ev.v) * (ov.v - ev.v) / ev.v;
      }
      final df = (o.rows > 1 && o.cols > 1)
          ? (o.rows - 1) * (o.cols - 1)
          : o.length - 1;
      return stableResult(Special.gammaQ(df / 2, chi / 2));
    },
    aliases: ['CHITEST'],
    examples: ['CHISQ.TEST(A1:B6, C1:D6)'],
    seeAlso: ['CHISQ.DIST.RT'],
  );
  b.fn(
    'MARGINOFERROR',
    'Calculates the amount of random sampling error given a range of values and a confidence level.',
    [
      P.range(
        'range',
        'The range of values used to calculate the margin of error.',
      ),
      P.num('confidence', 'The desired confidence level between (0, 1).'),
    ],
    (a) {
      final c = a.number(1);
      final xs = a.numbers(from: 0, to: 1);
      if (c <= 0 || c >= 1) fail(ErrorKind.num);
      final n = xs.length;
      final s = math.sqrt(variance(a, xs, sample: true));
      return stableResult(
        Special.tInvUpper((1 - c) / 2, n - 1.0) * s / math.sqrt(n),
      );
    },
    priority: Priority.p2,
    examples: ['MARGINOFERROR(A2:A100, 0.95)'],
    seeAlso: ['CONFIDENCE.T', 'STDEV'],
    notes:
        'Student-t based: T.INV.2T(1 − confidence, n − 1) · STDEV(range) / √n.',
  );
}
