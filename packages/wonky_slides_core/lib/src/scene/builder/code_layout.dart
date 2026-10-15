/// The code element layout of the scene builder (07 §3).
///
/// SL-10 shipped a basic layout here until SL-26's `CodeElementModel`; the
/// name is kept as an alias of `CodeElementLayout` (`core/code/`).
library;

import '../../code/code_element_layout.dart';

/// The core's code layout (alias of [CodeElementLayout]).
typedef BasicCodeLayout = CodeElementLayout;
