/// The role a user holds on a drive item (suite 06 §1).
///
/// Roles are ordered: `viewer < commenter < editor < owner`, so permission
/// checks read naturally: `if (role >= Role.editor) …`.
enum Role {
  /// Can read.
  viewer,

  /// Can read, comment and (in Write) suggest.
  commenter,

  /// Can edit content, share (unless disabled) and manage the item.
  editor,

  /// Full control, including transferring ownership and deleting forever.
  owner;

  /// Whether this role is at least [other].
  bool operator >=(Role other) => index >= other.index;

  /// Whether this role is strictly higher than [other].
  bool operator >(Role other) => index > other.index;

  /// Whether this role is at most [other].
  bool operator <=(Role other) => index <= other.index;

  /// Whether this role is strictly lower than [other].
  bool operator <(Role other) => index < other.index;

  /// Can create, reply to and resolve comments.
  bool get canComment => this >= Role.commenter;

  /// Can suggest changes (Write suggestion mode).
  bool get canSuggest => this >= Role.commenter;

  /// Can edit content.
  bool get canEdit => this >= Role.editor;

  /// Can rename, move, trash and restore versions.
  bool get canManage => this >= Role.editor;

  /// Can view version history (suite 07 §5: Editors and Owners).
  bool get canViewHistory => this >= Role.editor;

  /// Can transfer ownership and delete forever.
  bool get isOwner => this == Role.owner;

  /// The higher of this role and [other].
  Role max(Role? other) => other == null || this >= other ? this : other;

  /// Parses a role by its [name]; returns null for unknown names.
  static Role? tryParse(String? name) {
    if (name == null) return null;
    for (final role in values) {
      if (role.name == name) return role;
    }
    return null;
  }

  /// The highest role in [roles], or null when empty.
  static Role? highest(Iterable<Role?> roles) {
    Role? best;
    for (final r in roles) {
      if (r == null) continue;
      best = r.max(best);
    }
    return best;
  }
}

/// Who performed an action (suite 05 §5, 07 §2.1).
enum ActorKind {
  /// A human using the app.
  user,

  /// An MCP client acting with a personal access token.
  mcp,

  /// The built-in AI assistant.
  ai,

  /// A Sheets script.
  script,

  /// The server itself (jobs, migrations).
  system;

  /// Parses an actor kind by [name]; unknown names map to [user].
  static ActorKind parse(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => ActorKind.user);
}
