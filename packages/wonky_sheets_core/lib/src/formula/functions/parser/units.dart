/// The CONVERT unit table (Excel / Google Sheets unit names, 05 §15.15).
library;

/// Measurement quantity of a unit; units convert only within the same quantity.
enum Quantity {
  mass,
  distance,
  time,
  pressure,
  force,
  energy,
  power,
  magnetism,
  temperature,
  volume,
  area,
  information,
  speed,
}

/// A unit: [factor] SI base units per unit (gram, meter, second, pascal, newton, joule, watt,
/// tesla, kelvin, m³, m², bit, m/s). [power] is the exponent applied to metric prefixes
/// (`km2` = (10³)² m²). Temperatures convert through [toKelvin] / [fromKelvin].
final class Unit {
  final Quantity quantity;
  final double factor;
  final bool metric;
  final bool binary;
  final int power;

  const Unit(
    this.quantity,
    this.factor, {
    this.metric = false,
    this.binary = false,
    this.power = 1,
  });

  /// The unit scaled by a prefix multiplier.
  Unit scaled(double multiplier) =>
      Unit(quantity, factor * _pow(multiplier, power), power: power);

  static double _pow(double x, int n) {
    var r = 1.0;
    for (var i = 0; i < n; i++) {
      r *= x;
    }
    return r;
  }
}

/// Temperature scales: kelvin per degree and offset (K = value · scale + offset).
const Map<String, (double, double)> temperatureScales = {
  'C': (1, 273.15),
  'cel': (1, 273.15),
  'F': (5 / 9, 273.15 - 32 * 5 / 9),
  'fah': (5 / 9, 273.15 - 32 * 5 / 9),
  'K': (1, 0),
  'kel': (1, 0),
  'Rank': (5 / 9, 0),
  'Reau': (1.25, 273.15),
};

const double _in = 0.0254;
const double _ft = 0.3048;
const double _yd = 0.9144;
const double _mi = 1609.344;
const double _nmi = 1852;
const double _ly = 9460730472580800;
const double _pc = 3.0856775814913673e16;
const double _pica = _in / 72;
const double _lbf = 4.4482216152605;
const double _hp = 745.69987158227022;
const double _surveyFt = 1200 / 3937;

const Quantity _m = Quantity.mass;
const Quantity _d = Quantity.distance;
const Quantity _t = Quantity.time;
const Quantity _p = Quantity.pressure;
const Quantity _f = Quantity.force;
const Quantity _e = Quantity.energy;
const Quantity _w = Quantity.power;
const Quantity _g = Quantity.magnetism;
const Quantity _k = Quantity.temperature;
const Quantity _v = Quantity.volume;
const Quantity _a = Quantity.area;
const Quantity _i = Quantity.information;
const Quantity _s = Quantity.speed;

/// Units by exact (case-sensitive) name.
final Map<String, Unit> units = {
  // ---- mass (gram)
  'g': const Unit(_m, 1, metric: true),
  'sg': const Unit(_m, 14593.902937206364),
  'lbm': const Unit(_m, 453.59237),
  'u': const Unit(_m, 1.66053906660e-24, metric: true),
  'ozm': const Unit(_m, 28.349523125),
  'grain': const Unit(_m, 0.06479891),
  'cwt': const Unit(_m, 45359.237),
  'shweight': const Unit(_m, 45359.237),
  'uk_cwt': const Unit(_m, 50802.34544),
  'lcwt': const Unit(_m, 50802.34544),
  'hweight': const Unit(_m, 50802.34544),
  'stone': const Unit(_m, 6350.29318),
  'ton': const Unit(_m, 907184.74),
  'uk_ton': const Unit(_m, 1016046.9088),
  'LTON': const Unit(_m, 1016046.9088),
  'brton': const Unit(_m, 1016046.9088),
  // ---- distance (meter)
  'm': const Unit(_d, 1, metric: true),
  'mi': const Unit(_d, _mi),
  'Nmi': const Unit(_d, _nmi),
  'in': const Unit(_d, _in),
  'ft': const Unit(_d, _ft),
  'yd': const Unit(_d, _yd),
  'ang': const Unit(_d, 1e-10, metric: true),
  'ell': const Unit(_d, 1.143),
  'ly': const Unit(_d, _ly, metric: true),
  'parsec': const Unit(_d, _pc, metric: true),
  'pc': const Unit(_d, _pc, metric: true),
  'Picapt': const Unit(_d, _pica),
  'Pica': const Unit(_d, _pica),
  'pica': const Unit(_d, _in / 6),
  'survey_mi': const Unit(_d, 5280 * _surveyFt),
  // ---- time (second)
  'yr': const Unit(_t, 31557600),
  'day': const Unit(_t, 86400),
  'd': const Unit(_t, 86400),
  'hr': const Unit(_t, 3600),
  'mn': const Unit(_t, 60),
  'min': const Unit(_t, 60),
  'sec': const Unit(_t, 1, metric: true),
  's': const Unit(_t, 1, metric: true),
  // ---- pressure (pascal)
  'Pa': const Unit(_p, 1, metric: true),
  'p': const Unit(_p, 1, metric: true),
  'atm': const Unit(_p, 101325, metric: true),
  'at': const Unit(_p, 101325, metric: true),
  'mmHg': const Unit(_p, 101325 / 760, metric: true),
  'psi': const Unit(_p, _lbf / (_in * _in)),
  'Torr': const Unit(_p, 101325 / 760),
  // ---- force (newton)
  'N': const Unit(_f, 1, metric: true),
  'dyn': const Unit(_f, 1e-5, metric: true),
  'dy': const Unit(_f, 1e-5, metric: true),
  'lbf': const Unit(_f, _lbf),
  'pond': const Unit(_f, 9.80665e-3, metric: true),
  // ---- energy (joule)
  'J': const Unit(_e, 1, metric: true),
  'e': const Unit(_e, 1e-7, metric: true),
  'c': const Unit(_e, 4.184, metric: true),
  'cal': const Unit(_e, 4.1868, metric: true),
  'eV': const Unit(_e, 1.602176634e-19, metric: true),
  'ev': const Unit(_e, 1.602176634e-19, metric: true),
  'HPh': const Unit(_e, _hp * 3600),
  'hh': const Unit(_e, _hp * 3600),
  'Wh': const Unit(_e, 3600, metric: true),
  'wh': const Unit(_e, 3600, metric: true),
  'flb': const Unit(_e, _lbf * _ft),
  'BTU': const Unit(_e, 1055.05585262),
  'btu': const Unit(_e, 1055.05585262),
  // ---- power (watt)
  'HP': const Unit(_w, _hp),
  'h': const Unit(_w, _hp),
  'PS': const Unit(_w, 735.49875),
  'W': const Unit(_w, 1, metric: true),
  'w': const Unit(_w, 1, metric: true),
  // ---- magnetism (tesla)
  'T': const Unit(_g, 1, metric: true),
  'ga': const Unit(_g, 1e-4, metric: true),
  // ---- temperature (kelvin; affine scales in [temperatureScales])
  'C': const Unit(_k, 1),
  'cel': const Unit(_k, 1),
  'F': const Unit(_k, 1),
  'fah': const Unit(_k, 1),
  'K': const Unit(_k, 1, metric: true),
  'kel': const Unit(_k, 1, metric: true),
  'Rank': const Unit(_k, 1),
  'Reau': const Unit(_k, 1),
  // ---- volume (cubic meter)
  'tsp': const Unit(_v, 4.92892159375e-6),
  'tspm': const Unit(_v, 5e-6),
  'tbs': const Unit(_v, 1.478676478125e-5),
  'oz': const Unit(_v, 2.95735295625e-5),
  'cup': const Unit(_v, 2.365882365e-4),
  'pt': const Unit(_v, 4.73176473e-4),
  'us_pt': const Unit(_v, 4.73176473e-4),
  'uk_pt': const Unit(_v, 5.6826125e-4),
  'qt': const Unit(_v, 9.46352946e-4),
  'uk_qt': const Unit(_v, 1.1365225e-3),
  'gal': const Unit(_v, 3.785411784e-3),
  'uk_gal': const Unit(_v, 4.54609e-3),
  'l': const Unit(_v, 1e-3, metric: true),
  'L': const Unit(_v, 1e-3, metric: true),
  'lt': const Unit(_v, 1e-3, metric: true),
  'ang3': const Unit(_v, 1e-30, metric: true, power: 3),
  'ang^3': const Unit(_v, 1e-30, metric: true, power: 3),
  'barrel': const Unit(_v, 0.158987294928),
  'bushel': const Unit(_v, 0.03523907016688),
  'ft3': const Unit(_v, _ft * _ft * _ft),
  'ft^3': const Unit(_v, _ft * _ft * _ft),
  'in3': const Unit(_v, _in * _in * _in),
  'in^3': const Unit(_v, _in * _in * _in),
  'ly3': const Unit(_v, _ly * _ly * _ly, metric: true, power: 3),
  'ly^3': const Unit(_v, _ly * _ly * _ly, metric: true, power: 3),
  'm3': const Unit(_v, 1, metric: true, power: 3),
  'm^3': const Unit(_v, 1, metric: true, power: 3),
  'mi3': const Unit(_v, _mi * _mi * _mi),
  'mi^3': const Unit(_v, _mi * _mi * _mi),
  'yd3': const Unit(_v, _yd * _yd * _yd),
  'yd^3': const Unit(_v, _yd * _yd * _yd),
  'Nmi3': const Unit(_v, _nmi * _nmi * _nmi),
  'Nmi^3': const Unit(_v, _nmi * _nmi * _nmi),
  'Picapt3': const Unit(_v, _pica * _pica * _pica),
  'Picapt^3': const Unit(_v, _pica * _pica * _pica),
  'Pica3': const Unit(_v, _pica * _pica * _pica),
  'Pica^3': const Unit(_v, _pica * _pica * _pica),
  'GRT': const Unit(_v, 2.8316846592),
  'regton': const Unit(_v, 2.8316846592),
  'MTON': const Unit(_v, 1.13267386368),
  // ---- area (square meter)
  'uk_acre': const Unit(_a, 4046.8564224),
  'us_acre': const Unit(_a, 43560 * _surveyFt * _surveyFt),
  'ang2': const Unit(_a, 1e-20, metric: true, power: 2),
  'ang^2': const Unit(_a, 1e-20, metric: true, power: 2),
  'ar': const Unit(_a, 100, metric: true),
  'ft2': const Unit(_a, _ft * _ft),
  'ft^2': const Unit(_a, _ft * _ft),
  'ha': const Unit(_a, 10000),
  'in2': const Unit(_a, _in * _in),
  'in^2': const Unit(_a, _in * _in),
  'ly2': const Unit(_a, _ly * _ly, metric: true, power: 2),
  'ly^2': const Unit(_a, _ly * _ly, metric: true, power: 2),
  'm2': const Unit(_a, 1, metric: true, power: 2),
  'm^2': const Unit(_a, 1, metric: true, power: 2),
  'Morgen': const Unit(_a, 2500),
  'mi2': const Unit(_a, _mi * _mi),
  'mi^2': const Unit(_a, _mi * _mi),
  'Nmi2': const Unit(_a, _nmi * _nmi),
  'Nmi^2': const Unit(_a, _nmi * _nmi),
  'Picapt2': const Unit(_a, _pica * _pica),
  'Picapt^2': const Unit(_a, _pica * _pica),
  'Pica2': const Unit(_a, _pica * _pica),
  'Pica^2': const Unit(_a, _pica * _pica),
  'yd2': const Unit(_a, _yd * _yd),
  'yd^2': const Unit(_a, _yd * _yd),
  // ---- information (bit)
  'bit': const Unit(_i, 1, metric: true, binary: true),
  'byte': const Unit(_i, 8, metric: true, binary: true),
  // ---- speed (meter per second)
  'admkn': const Unit(_s, 6080 * _ft / 3600),
  'kn': const Unit(_s, _nmi / 3600),
  'm/h': const Unit(_s, 1 / 3600, metric: true),
  'm/hr': const Unit(_s, 1 / 3600, metric: true),
  'm/s': const Unit(_s, 1, metric: true),
  'm/sec': const Unit(_s, 1, metric: true),
  'mph': const Unit(_s, _mi / 3600),
};

/// Metric prefixes (`da` is the only two-letter one).
const Map<String, double> metricPrefixes = {
  'Y': 1e24,
  'Z': 1e21,
  'E': 1e18,
  'P': 1e15,
  'T': 1e12,
  'G': 1e9,
  'M': 1e6,
  'k': 1e3,
  'h': 1e2,
  'da': 1e1,
  'd': 1e-1,
  'c': 1e-2,
  'm': 1e-3,
  'u': 1e-6,
  'n': 1e-9,
  'p': 1e-12,
  'f': 1e-15,
  'a': 1e-18,
  'z': 1e-21,
  'y': 1e-24,
};

/// Binary prefixes (information units only).
const Map<String, double> binaryPrefixes = {
  'Yi': 1208925819614629174706176.0,
  'Zi': 1180591620717411303424.0,
  'Ei': 1152921504606846976.0,
  'Pi': 1125899906842624.0,
  'Ti': 1099511627776.0,
  'Gi': 1073741824.0,
  'Mi': 1048576.0,
  'ki': 1024.0,
  'Ki': 1024.0,
};

final Map<String, (Unit, String)?> _resolved = {};

/// Resolves a unit name with an optional prefix; returns the (scaled) unit and its base name
/// (the base name keys [temperatureScales]), or null when unknown.
(Unit, String)? resolveUnit(String name) {
  if (_resolved.containsKey(name)) return _resolved[name];
  final r = _resolve(name);
  _resolved[name] = r;
  return r;
}

(Unit, String)? _resolve(String name) {
  final exact = units[name];
  if (exact != null) return (exact, name);
  if (name.length > 2) {
    final bp = binaryPrefixes[name.substring(0, 2)];
    final base = name.substring(2);
    final u = units[base];
    if (bp != null && u != null && u.binary) return (u.scaled(bp), base);
  }
  for (final len in const [2, 1]) {
    if (name.length <= len) continue;
    final mp = metricPrefixes[name.substring(0, len)];
    if (mp == null) continue;
    final base = name.substring(len);
    final u = units[base];
    if (u != null && u.metric) return (u.scaled(mp), base);
  }
  return null;
}
