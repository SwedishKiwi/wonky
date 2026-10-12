import 'dart:math' as math;

import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../helpers.dart';
import '../registry.dart';
import 'common.dart';
import 'special.dart';

const _cumDesc =
    'Whether to use the cumulative distribution function rather than the probability density function.';
const _cumMassDesc =
    'Whether to use the cumulative distribution function rather than the probability mass function.';

/// Degrees of freedom parameter [i] truncated, ≥ 1 (else `#NUM!`).
double _df(Args a, int i) {
  final d = trunc(a.number(i));
  if (d < 1 || d > 1e10) fail(ErrorKind.num);
  return d;
}

/// Probability in the open interval (0, 1).
double _pOpen(Args a, int i) {
  final p = a.number(i);
  if (p <= 0 || p >= 1) fail(ErrorKind.num);
  return p;
}

// -------------------------------------------------------------------- discrete kernels

double _binomPmf(double k, double n, double p) {
  if (p == 0) return k == 0 ? 1 : 0;
  if (p == 1) return k == n ? 1 : 0;
  return math.exp(
    Special.lnCombin(n, k) + k * math.log(p) + (n - k) * math.log(1 - p),
  );
}

double _binomCdf(double k, double n, double p) {
  if (k < 0) return 0;
  if (k >= n) return 1;
  if (n <= 1000) {
    var s = 0.0;
    for (var i = 0.0; i <= k; i++) {
      s += _binomPmf(i, n, p);
    }
    return math.min(s, 1);
  }
  return Special.betaI(1 - p, n - k, k + 1);
}

double _negBinomPmf(double f, double s, double p) {
  if (p == 1) return f == 0 ? 1 : 0;
  if (p == 0) return 0;
  return math.exp(
    Special.lnCombin(f + s - 1, s - 1) + s * math.log(p) + f * math.log(1 - p),
  );
}

double _poissonPmf(double x, double l) {
  if (l == 0) return x == 0 ? 1 : 0;
  return math.exp(-l + x * math.log(l) - Special.lnFactorial(x));
}

double _hypPmf(double k, double n, double kk, double nn) => math.exp(
  Special.lnCombin(kk, k) +
      Special.lnCombin(nn - kk, n - k) -
      Special.lnCombin(nn, n),
);

/// Probability distributions and their inverses (05 §15.2).
void registerDistributions(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.statistical;
  _registerNormal(b);
  _registerT(b);
  _registerChiF(b);
  _registerBetaGamma(b);
  _registerDiscrete(b);
  _registerOther(b);
}

// -------------------------------------------------------------------- normal family

void _registerNormal(FunctionRegistryBuilder b) {
  FValue normDist(Args a) {
    final x = a.number(0), m = a.number(1), s = a.number(2);
    final cum = a.boolean(3);
    if (s <= 0) fail(ErrorKind.num);
    final z = (x - m) / s;
    return stableResult(cum ? Special.normCdf(z) : Special.normPdf(z) / s);
  }

  b.fn(
    'NORM.DIST',
    'Returns the value of the normal distribution function (or normal cumulative distribution function) for a specified value, mean, and standard deviation.',
    [
      P.num('x', 'The input to the normal distribution function.'),
      P.num('mean', 'The mean of the normal distribution function.'),
      P.num(
        'standard_deviation',
        'The standard deviation of the normal distribution function.',
      ),
      P.bool_('cumulative', _cumDesc),
    ],
    normDist,
    aliases: ['NORMDIST'],
    examples: ['NORM.DIST(2.4, 1, 4, FALSE)'],
    seeAlso: ['NORM.INV', 'NORM.S.DIST'],
  );
  b.fn(
    'NORM.INV',
    'Returns the value of the inverse normal distribution function for a specified value, mean, and standard deviation.',
    [
      P.num('x', 'The input to the inverse normal distribution function.'),
      P.num('mean', 'The mean of the normal distribution function.'),
      P.num(
        'standard_deviation',
        'The standard deviation of the normal distribution function.',
      ),
    ],
    (a) {
      final p = _pOpen(a, 0), m = a.number(1), s = a.number(2);
      if (s <= 0) fail(ErrorKind.num);
      return stableResult(m + s * Special.normInv(p));
    },
    aliases: ['NORMINV'],
    examples: ['NORM.INV(0.75, 1, 4)'],
    seeAlso: ['NORM.DIST', 'NORM.S.INV'],
  );
  b.fn(
    'NORM.S.DIST',
    'Returns the value of the standard normal cumulative distribution function (or the probability density function) for a specified value.',
    [
      P.num('x', 'The input to the standard normal distribution function.'),
      P.bool_('cumulative', _cumDesc, true, true),
    ],
    (a) {
      final x = a.number(0);
      return stableResult(
        a.boolOr(1, true) ? Special.normCdf(x) : Special.normPdf(x),
      );
    },
    aliases: ['NORMSDIST'],
    examples: ['NORM.S.DIST(2.4, TRUE)'],
    seeAlso: ['NORM.S.INV', 'NORM.DIST'],
  );
  b.fn(
    'NORM.S.INV',
    'Returns the value of the inverse standard normal distribution function for a specified value.',
    [
      P.num(
        'x',
        'The input to the inverse standard normal distribution function.',
      ),
    ],
    (a) => stableResult(Special.normInv(_pOpen(a, 0))),
    aliases: ['NORMSINV'],
    examples: ['NORM.S.INV(0.75)'],
    seeAlso: ['NORM.S.DIST', 'NORM.INV'],
  );
  FValue logNorm(Args a, bool cum) {
    final x = a.number(0), m = a.number(1), s = a.number(2);
    if (x <= 0 || s <= 0) fail(ErrorKind.num);
    final z = (math.log(x) - m) / s;
    return stableResult(
      cum ? Special.normCdf(z) : Special.normPdf(z) / (x * s),
    );
  }

  final logParams = [
    P.num('x', 'The input to the lognormal distribution function.'),
    P.num('mean', 'The mean of the natural logarithm of x.'),
    P.num(
      'standard_deviation',
      'The standard deviation of the natural logarithm of x.',
    ),
  ];
  b.fn(
    'LOGNORM.DIST',
    'Returns the value of the lognormal distribution function (or the cumulative lognormal distribution function) with a given mean and standard deviation at a specified value.',
    [...logParams, P.bool_('cumulative', _cumDesc)],
    (a) => logNorm(a, a.boolean(3)),
    examples: ['LOGNORM.DIST(4, 4, 6, TRUE)'],
    seeAlso: ['LOGNORM.INV', 'NORM.DIST'],
  );
  b.fn(
    'LOGNORMDIST',
    'Returns the value of the lognormal cumulative distribution with given mean and standard deviation at a specified value.',
    logParams,
    (a) => logNorm(a, true),
    examples: ['LOGNORMDIST(4, 4, 6)'],
    seeAlso: ['LOGNORM.DIST', 'LOGINV'],
  );
  b.fn(
    'LOGNORM.INV',
    'Returns the value of the inverse lognormal cumulative distribution with given mean and standard deviation at a specified value.',
    [
      P.num(
        'x',
        'The input to the inverse lognormal cumulative distribution function.',
      ),
      P.num('mean', 'The mean of the natural logarithm of the distribution.'),
      P.num(
        'standard_deviation',
        'The standard deviation of the natural logarithm of the distribution.',
      ),
    ],
    (a) {
      final p = _pOpen(a, 0), m = a.number(1), s = a.number(2);
      if (s <= 0) fail(ErrorKind.num);
      return stableResult(math.exp(m + s * Special.normInv(p)));
    },
    aliases: ['LOGINV'],
    examples: ['LOGNORM.INV(0.4, 4, 6)'],
    seeAlso: ['LOGNORM.DIST'],
  );
  b.fn(
    'GAUSS',
    'Returns the probability that a standard normal random variable will be between the mean and z standard deviations from the mean.',
    [P.num('z', 'The number of standard deviations from the mean.')],
    (a) => stableResult(0.5 * Special.erf(a.number(0) / math.sqrt2)),
    examples: ['GAUSS(2)'],
    seeAlso: ['NORM.S.DIST', 'PHI'],
  );
  b.fn(
    'PHI',
    'Returns the value of the probability density function of the standard normal distribution.',
    [P.num('x', 'The value at which to evaluate the density.')],
    (a) => stableResult(Special.normPdf(a.number(0))),
    priority: Priority.p2,
    examples: ['PHI(0.75)'],
    seeAlso: ['NORM.S.DIST', 'GAUSS'],
  );
}

// -------------------------------------------------------------------- Student t

void _registerT(FunctionRegistryBuilder b) {
  final xDf = [
    P.num('x', 'The input to the t-distribution function.'),
    P.num('degrees_freedom', 'The number of degrees of freedom.'),
  ];
  b.fn(
    'T.DIST',
    'Returns the left-tailed Student\'s t-distribution, or its probability density function.',
    [...xDf, P.bool_('cumulative', _cumDesc)],
    (a) {
      final x = a.number(0), df = _df(a, 1);
      return stableResult(
        a.boolean(2) ? Special.tCdf(x, df) : Special.tPdf(x, df),
      );
    },
    examples: ['T.DIST(1, 3, TRUE)'],
    seeAlso: ['T.DIST.RT', 'T.DIST.2T', 'T.INV'],
  );
  b.fn(
    'T.DIST.2T',
    'Returns the two-tailed Student\'s t-distribution for a given value.',
    xDf,
    (a) {
      final x = a.number(0), df = _df(a, 1);
      if (x < 0) fail(ErrorKind.num);
      return stableResult(2 * Special.tSf(x, df));
    },
    examples: ['T.DIST.2T(1, 3)'],
    seeAlso: ['T.DIST', 'T.INV.2T'],
  );
  b.fn(
    'T.DIST.RT',
    'Returns the right-tailed Student\'s t-distribution for a given value.',
    xDf,
    (a) {
      final x = a.number(0), df = _df(a, 1);
      return stableResult(Special.tSf(x, df));
    },
    examples: ['T.DIST.RT(1, 3)'],
    seeAlso: ['T.DIST', 'T.DIST.2T'],
  );
  b.fn(
    'TDIST',
    'Calculates the probability for Student\'s t-distribution with a given input (x).',
    [...xDf, P.num('tails', 'Whether to use 1 or 2 distribution tails.')],
    (a) {
      final x = a.number(0), df = _df(a, 1);
      final tails = a.integer(2);
      if (x < 0 || (tails != 1 && tails != 2)) fail(ErrorKind.num);
      return stableResult(tails * Special.tSf(x, df));
    },
    priority: Priority.p2,
    examples: ['TDIST(1, 3, 2)'],
    seeAlso: ['T.DIST.RT', 'T.DIST.2T'],
  );
  final pDf = [
    P.num('probability', 'The probability associated with the t-distribution.'),
    P.num('degrees_freedom', 'The number of degrees of freedom.'),
  ];
  b.fn(
    'T.INV',
    'Calculates the negative inverse of the one-tailed TDIST function.',
    pDf,
    (a) {
      final p = _pOpen(a, 0), df = _df(a, 1);
      if (p == 0.5) return FNumber.zero;
      final t = p < 0.5
          ? -Special.tInvUpper(p, df)
          : Special.tInvUpper(1 - p, df);
      return stableResult(t);
    },
    examples: ['T.INV(0.35, 1)'],
    seeAlso: ['T.INV.2T', 'T.DIST'],
  );
  b.fn(
    'T.INV.2T',
    'Calculates the inverse of the two-tailed TDIST function.',
    pDf,
    (a) {
      final p = a.number(0), df = _df(a, 1);
      if (p <= 0 || p > 1) fail(ErrorKind.num);
      return stableResult(Special.tInvUpper(p / 2, df));
    },
    aliases: ['TINV'],
    examples: ['T.INV.2T(0.35, 1)'],
    seeAlso: ['T.INV', 'T.DIST.2T'],
  );
}

// -------------------------------------------------------------------- chi-square & F

void _registerChiF(FunctionRegistryBuilder b) {
  final xDf = [
    P.num('x', 'The input to the chi-squared distribution function.'),
    P.num('degrees_freedom', 'The number of degrees of freedom.'),
  ];
  b.fn(
    'CHISQ.DIST',
    'Calculates the left-tailed chi-squared distribution, often used in hypothesis testing.',
    [...xDf, P.bool_('cumulative', _cumDesc)],
    (a) {
      final x = a.number(0), k = _df(a, 1);
      if (x < 0) fail(ErrorKind.num);
      return stableResult(
        a.boolean(2) ? Special.gammaP(k / 2, x / 2) : Special.chiPdf(x, k),
      );
    },
    examples: ['CHISQ.DIST(3, 2, FALSE)'],
    seeAlso: ['CHISQ.DIST.RT', 'CHISQ.INV'],
  );
  b.fn(
    'CHISQ.DIST.RT',
    'Calculates the right-tailed chi-squared distribution, which is commonly used in hypothesis testing.',
    xDf,
    (a) {
      final x = a.number(0), k = _df(a, 1);
      if (x < 0) fail(ErrorKind.num);
      return stableResult(Special.gammaQ(k / 2, x / 2));
    },
    aliases: ['CHIDIST'],
    examples: ['CHISQ.DIST.RT(3, 2)'],
    seeAlso: ['CHISQ.DIST', 'CHISQ.INV.RT'],
  );
  final pDf = [
    P.num(
      'probability',
      'The probability associated with the chi-squared distribution.',
    ),
    P.num('degrees_freedom', 'The number of degrees of freedom.'),
  ];
  b.fn(
    'CHISQ.INV',
    'Calculates the inverse of the left-tailed chi-squared distribution.',
    pDf,
    (a) {
      final p = a.number(0), k = _df(a, 1);
      if (p < 0 || p >= 1) fail(ErrorKind.num);
      if (p == 0) return FNumber.zero;
      return stableResult(Special.gammaInv(p, k / 2, 2));
    },
    examples: ['CHISQ.INV(0.42, 2)'],
    seeAlso: ['CHISQ.DIST', 'CHISQ.INV.RT'],
  );
  b.fn(
    'CHISQ.INV.RT',
    'Calculates the inverse of the right-tailed chi-squared distribution.',
    pDf,
    (a) {
      final p = a.number(0), k = _df(a, 1);
      if (p <= 0 || p > 1) fail(ErrorKind.num);
      if (p == 1) return FNumber.zero;
      return stableResult(Special.gammaInv(p, k / 2, 2, upper: true));
    },
    aliases: ['CHIINV'],
    examples: ['CHISQ.INV.RT(0.42, 2)'],
    seeAlso: ['CHISQ.DIST.RT', 'CHISQ.INV'],
  );
  final fParams = [
    P.num('x', 'The input to the F distribution function.'),
    P.num('degrees_freedom1', 'The numerator degrees of freedom.'),
    P.num('degrees_freedom2', 'The denominator degrees of freedom.'),
  ];
  b.fn(
    'F.DIST',
    'Calculates the left-tailed F probability distribution (degree of diversity) for two data sets with given input x.',
    [...fParams, P.bool_('cumulative', _cumDesc)],
    (a) {
      final x = a.number(0), d1 = _df(a, 1), d2 = _df(a, 2);
      if (x < 0) fail(ErrorKind.num);
      return stableResult(
        a.boolean(3) ? Special.fCdf(x, d1, d2) : Special.fPdf(x, d1, d2),
      );
    },
    examples: ['F.DIST(15.35, 7, 6, FALSE)'],
    seeAlso: ['F.DIST.RT', 'F.INV'],
  );
  b.fn(
    'F.DIST.RT',
    'Calculates the right-tailed F probability distribution (degree of diversity) for two data sets with given input x.',
    fParams,
    (a) {
      final x = a.number(0), d1 = _df(a, 1), d2 = _df(a, 2);
      if (x < 0) fail(ErrorKind.num);
      return stableResult(Special.fSf(x, d1, d2));
    },
    aliases: ['FDIST'],
    examples: ['F.DIST.RT(15.35, 7, 6)'],
    seeAlso: ['F.DIST', 'F.INV.RT'],
  );
  final fpParams = [
    P.num(
      'probability',
      'A probability associated with the F cumulative distribution.',
    ),
    P.num('degrees_freedom1', 'The numerator degrees of freedom.'),
    P.num('degrees_freedom2', 'The denominator degrees of freedom.'),
  ];
  b.fn(
    'F.INV',
    'Calculates the inverse of the left-tailed F probability distribution.',
    fpParams,
    (a) {
      final p = a.number(0), d1 = _df(a, 1), d2 = _df(a, 2);
      if (p < 0 || p >= 1) fail(ErrorKind.num);
      if (p == 0) return FNumber.zero;
      return stableResult(Special.fInv(p, d1, d2));
    },
    examples: ['F.INV(0.42, 2, 3)'],
    seeAlso: ['F.DIST', 'F.INV.RT'],
  );
  b.fn(
    'F.INV.RT',
    'Calculates the inverse of the right-tailed F probability distribution.',
    fpParams,
    (a) {
      final p = a.number(0), d1 = _df(a, 1), d2 = _df(a, 2);
      if (p <= 0 || p > 1) fail(ErrorKind.num);
      if (p == 1) return FNumber.zero;
      return stableResult(Special.fInv(p, d1, d2, upper: true));
    },
    aliases: ['FINV'],
    examples: ['F.INV.RT(0.42, 2, 3)'],
    seeAlso: ['F.DIST.RT', 'F.INV'],
  );
}

// -------------------------------------------------------------------- beta & gamma

void _registerBetaGamma(FunctionRegistryBuilder b) {
  double betaX(Args a, int ix, int iLo, int iHi, double alpha, double beta) {
    final x = a.number(ix);
    final lo = a.has(iLo) ? a.number(iLo) : 0.0;
    final hi = a.has(iHi) ? a.number(iHi) : 1.0;
    if (alpha <= 0 || beta <= 0 || lo >= hi || x < lo || x > hi) {
      fail(ErrorKind.num);
    }
    return (x - lo) / (hi - lo);
  }

  final betaShape = [
    P.num('alpha', 'The first shape parameter of the distribution (> 0).'),
    P.num('beta', 'The second shape parameter of the distribution (> 0).'),
  ];
  final bounds = [
    P.num('lower_bound', 'The lower bound of the interval of x.', true, 0),
    P.num('upper_bound', 'The upper bound of the interval of x.', true, 1),
  ];
  b.fn(
    'BETA.DIST',
    'Returns the probability of a given value as defined by the beta distribution function.',
    [
      P.num('value', 'The value at which to evaluate the distribution.'),
      ...betaShape,
      P.bool_('cumulative', _cumDesc),
      ...bounds,
    ],
    (a) {
      final alpha = a.number(1), beta = a.number(2);
      final cum = a.boolean(3);
      final t = betaX(a, 0, 4, 5, alpha, beta);
      if (cum) return stableResult(Special.betaI(t, alpha, beta));
      final width =
          (a.has(5) ? a.number(5) : 1.0) - (a.has(4) ? a.number(4) : 0.0);
      return stableResult(Special.betaPdf(t, alpha, beta) / width);
    },
    priority: Priority.p2,
    examples: ['BETA.DIST(2, 8, 10, TRUE, 1, 3)'],
    seeAlso: ['BETA.INV', 'BETADIST'],
  );
  b.fn(
    'BETADIST',
    'Returns the probability of a given value as defined by the cumulative beta distribution function.',
    [
      P.num('value', 'The value at which to evaluate the distribution.'),
      ...betaShape,
      ...bounds,
    ],
    (a) {
      final alpha = a.number(1), beta = a.number(2);
      final t = betaX(a, 0, 3, 4, alpha, beta);
      return stableResult(Special.betaI(t, alpha, beta));
    },
    priority: Priority.p2,
    examples: ['BETADIST(2, 8, 10, 1, 3)'],
    seeAlso: ['BETA.DIST', 'BETAINV'],
  );
  b.fn(
    'BETA.INV',
    'Returns the value of the inverse beta distribution function for a given probability.',
    [
      P.num(
        'probability',
        'A probability associated with the beta distribution.',
      ),
      ...betaShape,
      ...bounds,
    ],
    (a) {
      final p = a.number(0), alpha = a.number(1), beta = a.number(2);
      final lo = a.has(3) ? a.number(3) : 0.0;
      final hi = a.has(4) ? a.number(4) : 1.0;
      if (p <= 0 || p > 1 || alpha <= 0 || beta <= 0 || lo >= hi) {
        fail(ErrorKind.num);
      }
      return stableResult(lo + (hi - lo) * Special.betaInv(p, alpha, beta));
    },
    aliases: ['BETAINV'],
    priority: Priority.p2,
    examples: ['BETA.INV(0.685470581, 8, 10, 1, 3)'],
    seeAlso: ['BETA.DIST'],
  );
  final gParams = [
    P.num('x', 'The input to the gamma distribution function.'),
    P.num('alpha', 'The shape parameter of the distribution.'),
    P.num('beta', 'The scale parameter of the distribution.'),
  ];
  b.fn(
    'GAMMA.DIST',
    'Calculates the gamma distribution, a two-parameter continuous probability distribution.',
    [...gParams, P.bool_('cumulative', _cumDesc)],
    (a) {
      final x = a.number(0), al = a.number(1), be = a.number(2);
      final cum = a.boolean(3);
      if (x < 0 || al <= 0 || be <= 0) fail(ErrorKind.num);
      return stableResult(
        cum ? Special.gammaP(al, x / be) : Special.gammaPdf(x, al, be),
      );
    },
    aliases: ['GAMMADIST'],
    examples: ['GAMMA.DIST(4, 2, 3, TRUE)'],
    seeAlso: ['GAMMA.INV', 'GAMMA'],
  );
  b.fn(
    'GAMMA.INV',
    'Returns the value of the inverse gamma cumulative distribution function for the specified probability and alpha and beta parameters.',
    [
      P.num(
        'probability',
        'The probability associated with the gamma distribution.',
      ),
      P.num('alpha', 'The shape parameter of the distribution.'),
      P.num('beta', 'The scale parameter of the distribution.'),
    ],
    (a) {
      final p = a.number(0), al = a.number(1), be = a.number(2);
      if (p < 0 || p >= 1 || al <= 0 || be <= 0) fail(ErrorKind.num);
      if (p == 0) return FNumber.zero;
      return stableResult(Special.gammaInv(p, al, be));
    },
    aliases: ['GAMMAINV'],
    examples: ['GAMMA.INV(0.42, 2, 3)'],
    seeAlso: ['GAMMA.DIST'],
  );
  b.fn(
    'GAMMA',
    'Returns the Gamma function evaluated at the specified value.',
    [P.num('number', 'The input to the Gamma function.')],
    (a) {
      final x = a.number(0);
      if (x == x.truncateToDouble() && x <= 0) fail(ErrorKind.num);
      return stableResult(Special.gamma(x));
    },
    examples: ['GAMMA(0.5)'],
    seeAlso: ['GAMMALN', 'GAMMA.DIST'],
  );
  b.fn(
    'GAMMALN',
    'Returns the logarithm of a specified Gamma function, base e (Euler\'s number).',
    [
      P.num(
        'value',
        'The input to the Gamma function. The natural logarithm of Gamma(value) will be returned.',
      ),
    ],
    (a) {
      final x = a.number(0);
      if (x <= 0) fail(ErrorKind.num);
      return stableResult(Special.lnGamma(x));
    },
    aliases: ['GAMMALN.PRECISE'],
    category: FunctionCategory.math,
    examples: ['GAMMALN(4)'],
    seeAlso: ['GAMMA'],
  );
}

// -------------------------------------------------------------------- discrete

void _registerDiscrete(FunctionRegistryBuilder b) {
  b.fn(
    'BINOM.DIST',
    'Calculates the probability of drawing a certain number of successes (or a maximum number of successes) in a certain number of tries given a population of a certain size containing a certain number of successes, with replacement of draws.',
    [
      P.num(
        'num_successes',
        'The number of successes for which to calculate the probability.',
      ),
      P.num('num_trials', 'The number of independent trials.'),
      P.num('prob_success', 'The probability of success in any given trial.'),
      P.bool_('cumulative', _cumMassDesc),
    ],
    (a) {
      final k = trunc(a.number(0)), n = trunc(a.number(1)), p = a.number(2);
      final cum = a.boolean(3);
      if (k < 0 || n < 0 || k > n || p < 0 || p > 1) fail(ErrorKind.num);
      return stableResult(cum ? _binomCdf(k, n, p) : _binomPmf(k, n, p));
    },
    aliases: ['BINOMDIST'],
    examples: ['BINOM.DIST(4, 100, 0.005, FALSE)'],
    seeAlso: ['BINOM.INV', 'NEGBINOM.DIST'],
  );
  b.fn(
    'BINOM.INV',
    'Calculates the smallest value for which the cumulative binomial distribution is greater than or equal to a specified criteria.',
    [
      P.num('num_trials', 'The number of independent (Bernoulli) trials.'),
      P.num('prob_success', 'The probability of success in any given trial.'),
      P.num('target_prob', 'The desired threshold probability.'),
    ],
    (a) {
      final n = trunc(a.number(0)), p = a.number(1), alpha = a.number(2);
      if (n < 0 || p < 0 || p > 1 || alpha < 0 || alpha > 1) {
        fail(ErrorKind.num);
      }
      var lo = 0.0, hi = n;
      while (lo < hi) {
        final mid = ((lo + hi) / 2).floorToDouble();
        if (_binomCdf(mid, n, p) >= alpha) {
          hi = mid;
        } else {
          lo = mid + 1;
        }
      }
      return FNumber(lo);
    },
    aliases: ['CRITBINOM'],
    priority: Priority.p2,
    examples: ['BINOM.INV(100, 0.5, 0.4)'],
    seeAlso: ['BINOM.DIST'],
  );
  final nb = [
    P.num('num_failures', 'The number of failures to model.'),
    P.num('num_successes', 'The number of successes to model.'),
    P.num('prob_success', 'The probability of success in any given trial.'),
  ];
  double nbArgs(Args a, List<double> out) {
    final f = trunc(a.number(0)), s = trunc(a.number(1)), p = a.number(2);
    if (f < 0 || s < 1 || p < 0 || p > 1) fail(ErrorKind.num);
    out.addAll([f, s]);
    return p;
  }

  b.fn(
    'NEGBINOM.DIST',
    'Calculates the probability of drawing a certain number of failures before a certain number of successes given a probability of success in independent trials.',
    [...nb, P.bool_('cumulative', _cumMassDesc)],
    (a) {
      final fs = <double>[];
      final p = nbArgs(a, fs);
      final f = fs[0], s = fs[1];
      if (!a.boolean(3)) return stableResult(_negBinomPmf(f, s, p));
      if (f <= 1000) {
        var r = 0.0;
        for (var i = 0.0; i <= f; i++) {
          r += _negBinomPmf(i, s, p);
        }
        return stableResult(math.min(r, 1));
      }
      return stableResult(Special.betaI(p, s, f + 1));
    },
    priority: Priority.p2,
    examples: ['NEGBINOM.DIST(10, 5, 0.25, TRUE)'],
    seeAlso: ['NEGBINOMDIST', 'BINOM.DIST'],
  );
  b.fn(
    'NEGBINOMDIST',
    'Calculates the probability of drawing a certain number of failures before a certain number of successes given a probability of success in independent trials.',
    nb,
    (a) {
      final fs = <double>[];
      final p = nbArgs(a, fs);
      return stableResult(_negBinomPmf(fs[0], fs[1], p));
    },
    priority: Priority.p2,
    examples: ['NEGBINOMDIST(10, 5, 0.25)'],
    seeAlso: ['NEGBINOM.DIST'],
  );
  b.fn(
    'POISSON.DIST',
    'Returns the value of the Poisson distribution function (or Poisson cumulative distribution function) for a specified value and mean.',
    [
      P.num('x', 'The input to the Poisson distribution function.'),
      P.num('mean', 'The mean of the Poisson distribution function.'),
      P.bool_('cumulative', _cumMassDesc, true, true),
    ],
    (a) {
      final x = trunc(a.number(0)), l = a.number(1);
      if (x < 0 || l < 0) fail(ErrorKind.num);
      if (!a.boolOr(2, true)) return stableResult(_poissonPmf(x, l));
      if (l == 0) return FNumber.one;
      return stableResult(Special.gammaQ(x + 1, l));
    },
    aliases: ['POISSON'],
    examples: ['POISSON.DIST(2, 1, TRUE)'],
    seeAlso: ['EXPON.DIST'],
  );
  final hyp = [
    P.num('num_successes', 'The desired number of successes.'),
    P.num('num_draws', 'The number of permitted draws.'),
    P.num(
      'successes_in_pop',
      'The total number of successes in the population.',
    ),
    P.num('pop_size', 'The total size of the population.'),
  ];
  List<double> hypArgs(Args a) {
    final k = trunc(a.number(0)), n = trunc(a.number(1));
    final kk = trunc(a.number(2)), nn = trunc(a.number(3));
    if (nn <= 0 || n <= 0 || n > nn || kk <= 0 || kk > nn || k < 0) {
      fail(ErrorKind.num);
    }
    if (k > math.min(n, kk) || k < math.max(0, n - nn + kk)) {
      fail(ErrorKind.num);
    }
    return [k, n, kk, nn];
  }

  b.fn(
    'HYPGEOM.DIST',
    'Calculates the probability of drawing a certain number of successes in a certain number of tries given a population of a certain size containing a certain number of successes, without replacement of draws.',
    [...hyp, P.bool_('cumulative', _cumMassDesc)],
    (a) {
      final [k, n, kk, nn] = hypArgs(a);
      if (!a.boolean(4)) return stableResult(_hypPmf(k, n, kk, nn));
      var r = 0.0;
      for (var i = math.max(0.0, n - nn + kk); i <= k; i++) {
        r += _hypPmf(i, n, kk, nn);
      }
      return stableResult(math.min(r, 1));
    },
    examples: ['HYPGEOM.DIST(4, 12, 20, 40, TRUE)'],
    seeAlso: ['HYPGEOMDIST', 'BINOM.DIST'],
  );
  b.fn(
    'HYPGEOMDIST',
    'Calculates the probability of drawing a certain number of successes in a certain number of tries given a population of a certain size containing a certain number of successes, without replacement of draws.',
    hyp,
    (a) {
      final [k, n, kk, nn] = hypArgs(a);
      return stableResult(_hypPmf(k, n, kk, nn));
    },
    examples: ['HYPGEOMDIST(4, 12, 20, 40)'],
    seeAlso: ['HYPGEOM.DIST'],
  );
}

// -------------------------------------------------------------------- other continuous

void _registerOther(FunctionRegistryBuilder b) {
  b.fn(
    'EXPON.DIST',
    'Returns the value of the exponential distribution function with a specified lambda at a specified value.',
    [
      P.num('x', 'The input to the exponential distribution function.'),
      P.num(
        'lambda',
        'The lambda to specify the exponential distribution function.',
      ),
      P.bool_('cumulative', _cumDesc),
    ],
    (a) {
      final x = a.number(0), l = a.number(1);
      final cum = a.boolean(2);
      if (x < 0 || l <= 0) fail(ErrorKind.num);
      final e = math.exp(-l * x);
      return stableResult(cum ? 1 - e : l * e);
    },
    aliases: ['EXPONDIST'],
    examples: ['EXPON.DIST(4, 0.5, FALSE)'],
    seeAlso: ['POISSON.DIST', 'GAMMA.DIST'],
  );
  b.fn(
    'WEIBULL.DIST',
    'Returns the value of the Weibull distribution function (or Weibull cumulative distribution function) for a specified shape and scale.',
    [
      P.num('x', 'The input to the Weibull distribution function.'),
      P.num(
        'shape',
        'The shape parameter of the Weibull distribution function.',
      ),
      P.num(
        'scale',
        'The scale parameter of the Weibull distribution function.',
      ),
      P.bool_('cumulative', _cumDesc),
    ],
    (a) {
      final x = a.number(0), k = a.number(1), l = a.number(2);
      final cum = a.boolean(3);
      if (x < 0 || k <= 0 || l <= 0) fail(ErrorKind.num);
      final t = math.pow(x / l, k).toDouble();
      if (cum) return stableResult(1 - math.exp(-t));
      return stableResult(k / l * math.pow(x / l, k - 1) * math.exp(-t));
    },
    aliases: ['WEIBULL'],
    priority: Priority.p2,
    examples: ['WEIBULL.DIST(2.4, 2, 3, FALSE)'],
    seeAlso: ['EXPON.DIST'],
  );
  b.fn(
    'CONFIDENCE.NORM',
    'Calculates the width of half the confidence interval for a normal distribution.',
    [
      P.num('alpha', 'One minus the desired confidence level.'),
      P.num('standard_deviation', 'The standard deviation of the population.'),
      P.num('pop_size', 'The size of the population.'),
    ],
    (a) {
      final al = a.number(0), s = a.number(1), n = trunc(a.number(2));
      if (al <= 0 || al >= 1 || s <= 0 || n < 1) fail(ErrorKind.num);
      return stableResult(-Special.normInv(al / 2) * s / math.sqrt(n));
    },
    aliases: ['CONFIDENCE'],
    examples: ['CONFIDENCE.NORM(0.05, 1.6, 250)'],
    seeAlso: ['CONFIDENCE.T', 'Z.TEST'],
  );
  b.fn(
    'CONFIDENCE.T',
    'Calculates the width of half the confidence interval for a Student\'s t-distribution.',
    [
      P.num('alpha', 'One minus the desired confidence level.'),
      P.num('standard_deviation', 'The standard deviation of the population.'),
      P.num('size', 'The size of the population.'),
    ],
    (a) {
      final al = a.number(0), s = a.number(1), n = trunc(a.number(2));
      if (al <= 0 || al >= 1 || s <= 0 || n < 1) fail(ErrorKind.num);
      if (n == 1) divZero(a);
      return stableResult(Special.tInvUpper(al / 2, n - 1) * s / math.sqrt(n));
    },
    examples: ['CONFIDENCE.T(0.05, 1.6, 250)'],
    seeAlso: ['CONFIDENCE.NORM', 'T.TEST'],
  );
}
