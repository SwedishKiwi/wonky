import '../registry.dart';
import 'descriptive.dart';
import 'distributions.dart';
import 'hypothesis.dart';
import 'regression.dart';
import 'subtotal.dart';

/// Statistical functions (05 §15.2), plus FREQUENCY and the LINEST family (§15.9, category
/// array), GAMMALN (math) and SUBTOTAL/AGGREGATE (§15.1, category math).
void registerStatistical(FunctionRegistryBuilder b) {
  registerDescriptive(b);
  registerDistributions(b);
  registerHypothesisTests(b);
  registerRegression(b);
  registerSubtotal(b);
  b.category = FunctionCategory.statistical;
}
