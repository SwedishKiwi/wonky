import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'shell_services.dart';

/// Access to the [ShellServices] from widgets.
abstract final class ShellScope {
  static ShellServices of(BuildContext context) =>
      Provider.of<ShellServices>(context, listen: false);

  static ShellServices? maybeOf(BuildContext context) {
    try {
      return Provider.of<ShellServices>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }
}
