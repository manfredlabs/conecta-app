import 'package:flutter/material.dart';

/// Centralized role colors used across the app.
/// Leader uses theme primary, so it requires a ThemeData parameter.
class RoleColors {
  static Color leader(ThemeData theme) => theme.colorScheme.primary;
  static const Color helper = Colors.teal;
  static const Color member = Colors.indigo;
  static const Color visitor = Colors.purple;
  static const Color inactive = Colors.grey;

  /// Returns the role color for a member based on their flags.
  static Color forMember({
    required ThemeData theme,
    required bool isLeader,
    required bool isHelper,
    required bool isVisitor,
    bool isActive = true,
  }) {
    if (!isActive) return inactive;
    if (isLeader) return leader(theme);
    if (isHelper) return helper;
    if (isVisitor) return visitor;
    return member;
  }

  /// Returns the role color from a snapshot role string.
  static Color forSnapshot(String role, ThemeData theme) {
    switch (role) {
      case 'leader':
        return leader(theme);
      case 'helper':
        return helper;
      case 'visitor':
        return visitor;
      default:
        return member;
    }
  }
}
