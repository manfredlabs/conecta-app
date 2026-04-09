import 'package:flutter/material.dart';
import '../models/cell_member_model.dart';

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

  /// Returns the role label for a cell member, distinguishing co-leader.
  /// [mainLeaderId] is the cell's leaderId (userId from cell doc).
  static String roleLabel(CellMember member, {String? mainLeaderId}) {
    if (member.isLeader) {
      final memberUserId = member.person?.userId;
      if (mainLeaderId != null && memberUserId != null && memberUserId != mainLeaderId) {
        return 'Co-líder';
      }
      return 'Líder';
    }
    if (member.isHelper) return 'Auxiliar';
    if (member.isVisitor) return 'Visitante';
    return 'Membro';
  }
}
