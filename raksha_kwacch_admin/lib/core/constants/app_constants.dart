import 'package:flutter/material.dart';

class AppConstants {
  static const List<(String, IconData, String)> navigationItems = [
    ('Overview', Icons.dashboard_outlined, '/overview'),
    ('Attendance', Icons.calendar_today_outlined, '/attendance'),
    ('Verification', Icons.verified_outlined, '/verification'),
    ('Blocked Students', Icons.block_outlined, '/blocked-students'),
    ('People', Icons.group_outlined, '/people'),
  ];
}
