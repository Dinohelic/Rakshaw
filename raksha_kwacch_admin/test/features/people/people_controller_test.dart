import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/features/people/domain/people_models.dart';
import 'package:raksha_kwacch_admin/features/people/data/demo_people_repository.dart';
import 'package:raksha_kwacch_admin/features/people/presentation/people_controller.dart';

void main() {
  group('PeopleController Unit Tests', () {
    late PeopleController controller;
    late DemoPeopleRepository repo;

    setUp(() async {
      repo = DemoPeopleRepository();
      controller = PeopleController(repo);

      // wait for load
      await Future.delayed(const Duration(milliseconds: 500));
    });

    test('Initial state loads correctly', () {
      expect(controller.currentTab, 0);
      expect(controller.totalItems, 12); // 12 students in demo data
      expect(controller.paginatedData.length, 10); // Page size 10
    });

    test('Search filters correctly by name', () {
      controller.setSearchQuery('Aarav');
      final data = controller.filteredData;
      expect(data.length, 1);
      expect((data.first as Student).name, 'Aarav Sharma');
    });

    test('Faculty filter works', () {
      controller.setStudentFacultyFilter('Medicine');
      final data = controller.filteredData;
      expect(data.length, 3);
      for (var s in data) {
        expect((s as Student).faculty, 'Medicine');
      }
    });

    test('Reset clears filters and search', () {
      controller.setSearchQuery('Aarav');
      controller.setStudentFacultyFilter('Medicine');

      controller.resetFilters();

      expect(controller.searchQuery, '');
      expect(controller.studentFacultyFilter, null);
      expect(controller.totalItems, 12);
    });

    test('Pagination Next/Previous works', () {
      expect(controller.currentPage, 1);
      controller.nextPage();
      expect(controller.currentPage, 2);
      expect(controller.paginatedData.length, 2); // 12 total -> 2 on page 2

      controller.previousPage();
      expect(controller.currentPage, 1);
      expect(controller.paginatedData.length, 10);
    });

    test('Sorting toggles correctly', () {
      controller.toggleSort('Name');
      expect(controller.sortColumn, 'Name');
      expect(controller.sortAscending, true);

      final firstA = (controller.filteredData.first as Student).name;

      controller.toggleSort('Name');
      expect(controller.sortAscending, false);
      final firstD = (controller.filteredData.first as Student).name;

      expect(firstA, isNot(equals(firstD)));
    });

    test('Switching tabs resets state and changes data', () {
      controller.setSearchQuery('Aarav');
      controller.setTab(1); // Guardians

      expect(controller.searchQuery, '');
      expect(controller.currentTab, 1);
      expect(controller.totalItems, 10); // 10 guardians in demo data
    });
  });
}
