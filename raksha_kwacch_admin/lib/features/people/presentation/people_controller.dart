import 'package:flutter/foundation.dart';

import '../domain/people_models.dart';
import '../domain/people_repository.dart';

class PeopleController extends ChangeNotifier {
  final PeopleRepository _repository;

  PeopleController(this._repository) {
    _loadData();
  }

  bool isLoading = false;
  int currentTab = 0; // 0: Students, 1: Guardians, 2: Drivers

  List<Student> _allStudents = [];
  List<Guardian> _allGuardians = [];
  List<Driver> _allDrivers = [];

  String searchQuery = '';

  // Student Filters
  String? studentFacultyFilter;
  TransportStatus? studentTransportStatusFilter;
  StudentApprovalStatus? studentApprovalStatusFilter;

  // Guardian Filters
  VerificationStatus? guardianVerificationStatusFilter;

  // Driver Filters
  OperationalStatus? driverOperationalStatusFilter;
  String? driverRouteFilter;

  // Sorting
  bool sortAscending = true;
  String? sortColumn;

  // Pagination
  int currentPage = 1;
  static const int pageSize = 10;

  Future<void> reloadStudents() async {
    final results = await Future.wait([
      _repository.getStudents(),
      _repository.getGuardians(),
    ]);
    _allStudents = results[0] as List<Student>;
    _allGuardians = results[1] as List<Guardian>;
    notifyListeners();
  }

  Future<Student> approveStudent(String studentId) async {
    final updated = await _repository.approveStudent(studentId);
    await reloadStudents();
    return updated;
  }

  Future<Student> rejectStudent({
    required String studentId,
    required String reason,
  }) async {
    final updated = await _repository.rejectStudent(
      studentId: studentId,
      reason: reason,
    );
    await reloadStudents();
    return updated;
  }

  Future<void> _loadData() async {
    isLoading = true;
    notifyListeners();

    try {
      // For simplicity, loading all upfront in the demo
      final results = await Future.wait([
        _repository.getStudents(),
        _repository.getGuardians(),
        _repository.getDrivers(),
      ]);

      _allStudents = results[0] as List<Student>;
      _allGuardians = results[1] as List<Guardian>;
      _allDrivers = results[2] as List<Driver>;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setTab(int index) {
    if (currentTab != index) {
      currentTab = index;
      _resetFiltersAndSearch();
      _loadData(); // Simulate loading on tab switch as requested
    }
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    currentPage = 1;
    notifyListeners();
  }

  void setStudentFacultyFilter(String? faculty) {
    studentFacultyFilter = faculty;
    currentPage = 1;
    notifyListeners();
  }

  void setStudentTransportStatusFilter(TransportStatus? status) {
    studentTransportStatusFilter = status;
    currentPage = 1;
    notifyListeners();
  }

  void setStudentApprovalStatusFilter(StudentApprovalStatus? status) {
    studentApprovalStatusFilter = status;
    currentPage = 1;
    notifyListeners();
  }

  void setGuardianVerificationStatusFilter(VerificationStatus? status) {
    guardianVerificationStatusFilter = status;
    currentPage = 1;
    notifyListeners();
  }

  void setDriverOperationalStatusFilter(OperationalStatus? status) {
    driverOperationalStatusFilter = status;
    currentPage = 1;
    notifyListeners();
  }

  void setDriverRouteFilter(String? route) {
    driverRouteFilter = route;
    currentPage = 1;
    notifyListeners();
  }

  void resetFilters() {
    _resetFiltersAndSearch();
    notifyListeners();
  }

  void _resetFiltersAndSearch() {
    searchQuery = '';
    studentFacultyFilter = null;
    studentTransportStatusFilter = null;
    studentApprovalStatusFilter = null;
    guardianVerificationStatusFilter = null;
    driverOperationalStatusFilter = null;
    driverRouteFilter = null;
    sortColumn = null;
    sortAscending = true;
    currentPage = 1;
  }

  void toggleSort(String column) {
    if (sortColumn == column) {
      sortAscending = !sortAscending;
    } else {
      sortColumn = column;
      sortAscending = true;
    }
    currentPage = 1;
    notifyListeners();
  }

  void nextPage() {
    if (currentPage < totalPages) {
      currentPage++;
      notifyListeners();
    }
  }

  void previousPage() {
    if (currentPage > 1) {
      currentPage--;
      notifyListeners();
    }
  }

  // Derived properties for current tab
  List<dynamic> get filteredData {
    switch (currentTab) {
      case 0:
        return _filteredStudents();
      case 1:
        return _filteredGuardians();
      case 2:
        return _filteredDrivers();
      default:
        return [];
    }
  }

  List<dynamic> get paginatedData {
    final data = filteredData;
    final startIndex = (currentPage - 1) * pageSize;
    if (startIndex >= data.length) return [];
    return data.skip(startIndex).take(pageSize).toList();
  }

  int get totalItems => filteredData.length;
  int get totalPages => (totalItems / pageSize).ceil();

  // Helper for student name lookup by guardian
  String getStudentName(String studentId) {
    try {
      return _allStudents.firstWhere((s) => s.id == studentId).name;
    } catch (_) {
      return 'Unknown';
    }
  }

  List<Student> _filteredStudents() {
    var list = _allStudents.where((s) {
      bool matchesSearch = true;
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        matchesSearch =
            s.name.toLowerCase().contains(q) ||
            s.enrollmentNumber.toLowerCase().contains(q);
      }
      bool matchesFaculty =
          studentFacultyFilter == null || s.faculty == studentFacultyFilter;
      bool matchesStatus =
          studentTransportStatusFilter == null ||
          s.transportStatus == studentTransportStatusFilter;
      bool matchesApproval =
          studentApprovalStatusFilter == null ||
          s.approvalStatus == studentApprovalStatusFilter;

      return matchesSearch &&
          matchesFaculty &&
          matchesStatus &&
          matchesApproval;
    }).toList();

    if (sortColumn != null) {
      list.sort((a, b) {
        int cmp = 0;
        if (sortColumn == 'Name') {
          cmp = a.name.compareTo(b.name);
        } else if (sortColumn == 'Enrollment No.') {
          cmp = a.enrollmentNumber.compareTo(b.enrollmentNumber);
        }
        return sortAscending ? cmp : -cmp;
      });
    }

    return list;
  }

  List<Guardian> _filteredGuardians() {
    var list = _allGuardians.where((g) {
      bool matchesSearch = true;
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final studentName = getStudentName(g.linkedStudentId).toLowerCase();
        matchesSearch =
            g.name.toLowerCase().contains(q) || studentName.contains(q);
      }
      bool matchesStatus =
          guardianVerificationStatusFilter == null ||
          g.verificationStatus == guardianVerificationStatusFilter;

      return matchesSearch && matchesStatus;
    }).toList();

    if (sortColumn != null) {
      list.sort((a, b) {
        int cmp = 0;
        if (sortColumn == 'Name') {
          cmp = a.name.compareTo(b.name);
        }
        return sortAscending ? cmp : -cmp;
      });
    }

    return list;
  }

  List<Driver> _filteredDrivers() {
    var list = _allDrivers.where((d) {
      bool matchesSearch = true;
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        matchesSearch =
            d.name.toLowerCase().contains(q) ||
            d.driverId.toLowerCase().contains(q);
      }
      bool matchesStatus =
          driverOperationalStatusFilter == null ||
          d.operationalStatus == driverOperationalStatusFilter;
      bool matchesRoute =
          driverRouteFilter == null || d.routeCode == driverRouteFilter;

      return matchesSearch && matchesStatus && matchesRoute;
    }).toList();

    if (sortColumn != null) {
      list.sort((a, b) {
        int cmp = 0;
        if (sortColumn == 'Name') {
          cmp = a.name.compareTo(b.name);
        } else if (sortColumn == 'Driver ID') {
          cmp = a.driverId.compareTo(b.driverId);
        }
        return sortAscending ? cmp : -cmp;
      });
    }

    return list;
  }

  // Filter option lists
  List<String> get availableFaculties =>
      _allStudents.map((e) => e.faculty).toSet().toList()..sort();
  List<String> get availableRoutes =>
      _allDrivers.map((e) => e.routeCode).toSet().toList()..sort();
}
