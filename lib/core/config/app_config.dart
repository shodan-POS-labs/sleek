enum Environment { dev, prod }

class AppConfig {
  static const String environmentString = String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');

  static Environment get environment {
    switch (environmentString.toLowerCase()) {
      case 'prod':
      case 'production':
        return Environment.prod;
      case 'dev':
      case 'development':
      default:
        return Environment.dev;
    }
  }

  static bool get isProduction => environment == Environment.prod;
  static bool get isDevelopment => environment == Environment.dev;

  static String get apiBaseUrl {
    return isProduction 
      ? 'https://api.sleekpos.com/v1' 
      : 'https://api-dev.sleekpos.com/v1';
  }
}
