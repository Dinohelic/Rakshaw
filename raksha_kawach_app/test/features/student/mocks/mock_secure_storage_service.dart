import 'package:raksha_kawach_app/core/constants/app_constants.dart';
import 'package:raksha_kawach_app/core/storage/secure_storage_service.dart';

class MockSecureStorageService extends SecureStorageService {
  final Map<String, String> _store = {};

  MockSecureStorageService({Map<String, String>? initialValues}) {
    if (initialValues != null) {
      _store.addAll(initialValues);
    }
  }

  @override
  Future<void> saveToken(String token) async {
    _store[AppConstants.tokenKey] = token;
  }

  @override
  Future<String?> getToken() async {
    return _store[AppConstants.tokenKey];
  }

  @override
  Future<void> clearToken() async {
    _store.remove(AppConstants.tokenKey);
  }

  @override
  Future<void> setLocationSharingConsent(String studentId, bool enabled) async {
    _store['location_sharing_consent_$studentId'] = enabled ? 'true' : 'false';
  }

  @override
  Future<bool> getLocationSharingConsent(String studentId) async {
    return _store['location_sharing_consent_$studentId'] == 'true';
  }

  @override
  Future<bool?> getLocationSharingConsentState(String studentId) async {
    final val = _store['location_sharing_consent_$studentId'];
    if (val == null) return null;
    return val == 'true';
  }

  @override
  Future<void> clearLocationSharingConsent(String studentId) async {
    _store.remove('location_sharing_consent_$studentId');
  }

  static const String _mockRememberMeKey = 'raksha_remember_me_preference';

  @override
  Future<void> setRememberMe(bool enabled) async {
    _store[_mockRememberMeKey] = enabled ? 'true' : 'false';
  }

  @override
  Future<bool> getRememberMe() async {
    final val = _store[_mockRememberMeKey];
    if (val == null) return true;
    return val == 'true';
  }

  @override
  Future<void> clearRememberMe() async {
    _store.remove(_mockRememberMeKey);
  }

  void reset() {
    _store.clear();
  }
}

