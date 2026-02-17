class ApiConfig {
  ApiConfig._();

  static const bool isProd = bool.fromEnvironment('PROD', defaultValue: false);
  static const String _prodBaseUrl = 'https://ls-api.hence.events';
  // static const String _devBaseUrl = 'https://ls-api-dev.hence.events';
  static const String _devBaseUrl = 'http://localhost:3000';

  static const String baseUrl = isProd ? _prodBaseUrl : _devBaseUrl;
}
