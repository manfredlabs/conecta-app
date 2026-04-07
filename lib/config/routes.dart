import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/shell/main_shell.dart';
import '../screens/hierarchy/supervision_list_screen.dart';
import '../screens/hierarchy/supervision_hub_screen.dart';
import '../screens/hierarchy/edit_supervision_screen.dart';
import '../screens/hierarchy/edit_congregation_screen.dart';
import '../screens/hierarchy/cell_list_screen.dart';
import '../screens/hierarchy/congregation_cells_screen.dart';
import '../screens/hierarchy/congregation_hub_screen.dart';
import '../screens/cells/cell_hub_screen.dart';
import '../screens/cells/cell_members_screen.dart';
import '../screens/cells/edit_cell_screen.dart';
import '../screens/members/add_member_screen.dart';
import '../screens/members/edit_member_screen.dart';
import '../screens/meetings/create_meeting_screen.dart';
import '../screens/meetings/meeting_detail_screen.dart';
import '../screens/meetings/add_visitor_screen.dart';
import '../screens/meetings/edit_meeting_screen.dart';
import '../screens/meetings/cell_meetings_screen.dart';
import '../screens/meetings/supervision_meetings_screen.dart';
import '../screens/meetings/congregation_meetings_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/members/supervision_members_screen.dart';
import '../screens/members/congregation_members_screen.dart';
import '../screens/approvals/approval_requests_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String supervisionList = '/supervision-list';
  static const String supervisionHub = '/supervision-hub';
  static const String editSupervision = '/edit-supervision';
  static const String editCongregation = '/edit-congregation';
  static const String cellList = '/cell-list';
  static const String cellHub = '/cell-hub';
  static const String cellMembers = '/cell-members';
  static const String cellMeetings = '/cell-meetings';
  static const String editCell = '/edit-cell';
  static const String addMember = '/add-member';
  static const String editMember = '/edit-member';
  static const String createMeeting = '/create-meeting';
  static const String meetingDetail = '/meeting-detail';
  static const String editMeeting = '/edit-meeting';
  static const String supervisionMeetings = '/supervision-meetings';
  static const String congregationMeetings = '/congregation-meetings';
  static const String congregationCells = '/congregation-cells';
  static const String congregationHub = '/congregation-hub';
  static const String addVisitor = '/add-visitor';
  static const String editProfile = '/edit-profile';
  static const String supervisionMembers = '/supervision-members';
  static const String congregationMembers = '/congregation-members';
  static const String approvalRequests = '/approval-requests';

  static Map<String, WidgetBuilder> get routes => {
        login: (_) => const LoginScreen(),
        home: (_) => const MainShell(),
        supervisionList: (_) => const SupervisionListScreen(),
        supervisionHub: (_) => const SupervisionHubScreen(),
        editSupervision: (_) => const EditSupervisionScreen(),
        editCongregation: (_) => const EditCongregationScreen(),
        cellList: (_) => const CellListScreen(),
        cellHub: (_) => const CellHubScreen(),
        cellMembers: (_) => const CellMembersScreen(),
        cellMeetings: (_) => const CellMeetingsScreen(),
        editCell: (_) => const EditCellScreen(),
        addMember: (_) => const AddMemberScreen(),
        editMember: (_) => const EditMemberScreen(),
        createMeeting: (_) => const CreateMeetingScreen(),
        meetingDetail: (_) => const MeetingDetailScreen(),
        editMeeting: (_) => const EditMeetingScreen(),
        addVisitor: (_) => const AddVisitorScreen(),
        supervisionMeetings: (_) => const SupervisionMeetingsScreen(),
        congregationMeetings: (_) => const CongregationMeetingsScreen(),
        congregationCells: (_) => const CongregationCellsScreen(),
        congregationHub: (_) => const CongregationHubScreen(),
        editProfile: (_) => const EditProfileScreen(),
        supervisionMembers: (_) => const SupervisionMembersScreen(),
        congregationMembers: (_) => const CongregationMembersScreen(),
        approvalRequests: (_) => const ApprovalRequestsScreen(),
      };
}
