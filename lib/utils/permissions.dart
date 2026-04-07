import '../models/user_model.dart';
import '../models/cell_model.dart';
import '../models/supervision_model.dart';

class Permissions {
  // ── Cell ──

  static bool canEditCell(AppUser user, CellGroup cell) {
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
    if (user.role == UserRole.supervisor &&
        user.supervisionId != null &&
        user.supervisionId == supervisionId) {
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

  static bool canManageMembers(AppUser user, CellGroup cell) {
    return canEditCell(user, cell);
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
    return false;
  }

  // ── Meetings ──

  static bool canCreateMeeting(AppUser user, CellGroup cell) {
    return canEditCell(user, cell);
  }

  static bool canEditMeeting(AppUser user, CellGroup cell) {
    return canEditCell(user, cell);
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
