import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/cells/cell_detail_screen.dart';
import '../screens/members/add_member_screen.dart';
import '../screens/meetings/create_meeting_screen.dart';
import '../screens/meetings/meeting_detail_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String cellDetail = '/cell-detail';
  static const String addMember = '/add-member';
  static const String createMeeting = '/create-meeting';
  static const String meetingDetail = '/meeting-detail';

  static Map<String, WidgetBuilder> get routes => {
        login: (_) => const LoginScreen(),
        home: (_) => const HomeScreen(),
        cellDetail: (_) => const CellDetailScreen(),
        addMember: (_) => const AddMemberScreen(),
        createMeeting: (_) => const CreateMeetingScreen(),
        meetingDetail: (_) => const MeetingDetailScreen(),
      };
}
