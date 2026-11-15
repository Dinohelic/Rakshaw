import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:raksha_kawach_app/features/student/services/location_service.dart';

class MockLocationService implements LocationService {
  bool serviceEnabled;
  LocationPermission permission;
  Position? currentPosition;
  bool appSettingsOpened = false;
  bool locationSettingsOpened = false;
  bool shouldThrow = false;
  StreamController<Position>? positionStreamController;

  MockLocationService({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.currentPosition,
  });

  @override
  Future<bool> isLocationServiceEnabled() async {
    if (shouldThrow) throw Exception('Location service check failed');
    return serviceEnabled;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    return permission;
  }

  @override
  Future<Position?> getCurrentPosition() async {
    if (shouldThrow) throw Exception('GPS hardware error');
    return currentPosition ??
        Position(
          latitude: 28.4595,
          longitude: 76.9266,
          timestamp: DateTime.now(),
          accuracy: 15.0,
          altitude: 200.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );
  }

  @override
  Stream<Position> getPositionStream({Duration? intervalDuration}) {
    positionStreamController ??= StreamController<Position>.broadcast();
    return positionStreamController!.stream;
  }

  void emitPosition(Position position) {
    positionStreamController ??= StreamController<Position>.broadcast();
    positionStreamController!.add(position);
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened = true;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened = true;
    return true;
  }

  void dispose() {
    positionStreamController?.close();
  }
}
