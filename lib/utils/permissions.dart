import '../models/user_model.dart';
import '../models/cell_model.dart';
import '../models/cell_member_model.dart';
import '../models/supervision_model.dart';

class Permissions {
  // ── Cell ──

  static bool canEditCell(AppUser user, CellGroup cell, {List<CellMember>? cellMembers}) {
    if (user.role == UserRole.admin) {
      return true;
    }
    if (user.role == UserRole.pastor &&
        user.congregationId == cell.congregationId) {
      return true;
    }
    if (user.role == UserRole.supervisor &&
        user.supervisionId == cell.supervisionId) {
      return true;
    }
    if (user.role == UserRole.leader && user.cellId == cell.id) {
      return true;
    }
    // Check if user is leader of this cell via cell_members (multi-cell leaders)
    if (user.personId != null && cellMembers != null) {
      final isLeaderHere = cellMembers.any((m) =>
          m.personId == user.personId && m.isLeader && m.isActive);
      if (isLeaderHere) return true;
    }
    return false;
  }

  static bool canCreateCell(
      AppUser user, {String? supervisionId, String? congregationId}) {
    if (user.role == UserRole.admin) {
      return true;
    }
    if (user.role == UserRole.pastor &&
        user.congregationId != null &&
        user.congregationId == congregationId) {
      return true;
    }
    return false;
  }

  static bool canDeleteCell(AppUser user, CellGroup cell) {
    return canCreateCell(user,
        supervisionId: cell.supervisionId,
        congregationId: cell.congregationId);
  }

  // ── Members ──

  static bool canManageMembers(AppUser user, CellGroup cell, {List<CellMember>? cellMembers}) {
    return canEditCell(user, cell, cellMembers: cellMembers);
  }

  static bool canPromoteToLeader(AppUser user, CellGroup cell) {
    if (user.role == UserRole.admin) {
      return true;
    }
    if (user.role == UserRole.pastor &&
        user.congregationId == cell.congregationId) {
      return true;
    }
    if (user.role == UserRole.supervisor &&
        user.supervisionId == cell.supervisionId) {
      return true;
    }
    if (user.role == UserRole.leader && user.id == cell.leaderId) {
      return true;
    }
    return false;
  }

  // ── Meetings ──

  static bool canCreateMeeting(AppUser user, CellGroup cell, {List<CellMember>? cellMembers}) {
    return canEditCell(user, cell, cellMembers: cellMembers);
  }

  static bool canEditMeeting(AppUser user, CellGroup cell, {List<CellMember>? cellMembers}) {
    return canEditCell(user, cell, cellMembers: cellMembers);
  }

  // ── Supervision ──

  static bool canEditSupervision(AppUser user, Supervision supervision) {
    if (user.role == UserRole.admin) {
      return true;
    }
    if (user.role == UserRole.pastor &&
        user.congregationId == supervision.congregationId) {
      return true;
    }
    if (user.role == UserRole.supervisor &&
        user.supervisionId == supervision.id) {
      return true;
    }
    return false;
  }

  static bool canCreateSupervision(AppUser user, {String? congregationId}) {
    if (user.role == UserRole.admin) {
      return true;
    }
    if (user.role == UserRole.pastor &&
        user.congregationId != null &&
        user.congregationId == congregationId) {
      return true;
    }
    return false;
  }

  // ── Congregation ──

  static bool canEditCongregation(AppUser user, {String? congregationId}) {
    if (user.role == UserRole.admin) {
      return true;
    }
    if (user.role == UserRole.pastor &&
        user.congregationId == congregationId) {
      return true;
    }
    return false;
  }

  static bool canCreateCongregation(AppUser user) {
    return user.role == UserRole.admin;
  }
}
