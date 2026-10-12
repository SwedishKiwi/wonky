import '../../values/errors.dart';
import '../registry.dart';
import 'cash_flows.dart';
import 'depreciation.dart';
import 'securities.dart';
import 'tvm.dart';

/// Financial functions (05 §15.7).
void registerFinancial(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.financial;
  registerTvm(b);
  registerCashFlows(b);
  registerDepreciation(b);
  registerSecurities(b);

  // Excel-only odd-period securities and French degressive depreciation (not supported).
  const unsupported = {
    'ODDFPRICE':
        'Returns the price per 100 face value of a security with an odd first period.',
    'ODDFYIELD': 'Returns the yield of a security with an odd first period.',
    'ODDLPRICE':
        'Returns the price per 100 face value of a security with an odd last period.',
    'ODDLYIELD': 'Returns the yield of a security with an odd last period.',
    'AMORDEGRC':
        'Returns the depreciation for each accounting period using a depreciation coefficient (French accounting system).',
  };
  for (final MapEntry(key: name, value: summary) in unsupported.entries) {
    b.stub(name, summary, message: ErrorMessages.notAvailable(name));
  }
}
