class AppConstants {
  static const String appName = 'Raksha Kawach';
  static const String baseUrl = 'https://api.rakshakawach.edu';

  // Network Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);

  // Secure Storage Keys
  static const String tokenKey = 'jwt_token';

  // Validation Patterns
  // Alphanumeric enrollment number (e.g., STU001)
  static final RegExp enrollmentPattern = RegExp(r'^[a-zA-Z0-9]+$');
  // Exactly 10 digits for mobile number
  static final RegExp mobilePattern = RegExp(r'^[0-9]{10}$');
  // Email pattern for university email
  static final RegExp emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@sgtuniversity\.org$',
  );
}
