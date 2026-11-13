import 'package:flutter/material.dart';

class AppConstants {
  static const List<(String, IconData, String)> navigationItems = [
    ('Overview', Icons.dashboard_outlined, '/overview'),
    ('Live Tracking', Icons.fmd_good_outlined, '/tracking'),
    ('Attendance', Icons.calendar_today_outlined, '/attendance'),
    ('Verification', Icons.verified_outlined, '/verification'),
    ('Blocked Students', Icons.block_outlined, '/blocked-students'),
    ('Fleet & Routes', Icons.directions_bus_outlined, '/fleet'),
    ('People', Icons.group_outlined, '/people'),
    ('Alerts & Support', Icons.warning_amber_outlined, '/alerts'),
    ('Settings', Icons.settings_outlined, '/settings'),
  ];
}
