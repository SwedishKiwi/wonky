import 'package:wonky_core/wonky_core.dart' show Role;

import 'models.dart';

/// Conversions between the protocol enum [AccessRole] and the domain enum
/// [Role] (same order, specs/06 §1).
extension AccessRoleToRole on AccessRole {
  Role get role => Role.values[index];
}

extension RoleToAccessRole on Role {
  AccessRole get access => AccessRole.values[index];
}

/// The higher of two nullable roles.
Role? maxRole(Role? a, Role? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a >= b ? a : b;
}
