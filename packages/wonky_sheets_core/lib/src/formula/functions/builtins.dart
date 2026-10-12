import 'array/array.dart';
import 'database/database.dart';
import 'date_time/date_time.dart';
import 'engineering/engineering.dart';
import 'filter/filter.dart';
import 'financial/financial.dart';
import 'info/info.dart';
import 'lambda_helpers/lambda_helpers.dart';
import 'logical/logical.dart';
import 'lookup/lookup.dart';
import 'math/aggregate.dart';
import 'math/basic.dart';
import 'math/conditional.dart';
import 'math/misc.dart';
import 'math/rounding.dart';
import 'operator/operator.dart';
import 'parser/parser.dart';
import 'query/query_function.dart';
import 'registry.dart';
import 'statistical/statistical.dart';
import 'text/text.dart';
import 'web/web.dart';

/// Registers every built-in function category (05 §14.2), in Insert › Function order.
void registerBuiltins(FunctionRegistryBuilder b) {
  registerMathBasic(b);
  registerRounding(b);
  registerMathAggregate(b);
  registerConditional(b);
  registerMathMisc(b);
  registerStatistical(b);
  registerLookup(b);
  registerLogical(b);
  registerText(b);
  registerDateTime(b);
  registerFinancial(b);
  registerInfo(b);
  registerArray(b);
  registerFilter(b);
  registerDatabase(b);
  registerEngineering(b);
  registerParser(b);
  registerOperators(b);
  registerWeb(b);
  registerQuery(b);
  registerLambdaHelpers(b);
}
