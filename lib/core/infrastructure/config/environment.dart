enum Environment { dev, staging, prod }

extension EnvironmentX on Environment {
  String get name {
    switch (this) {
      case Environment.dev:
        return 'dev';
      case Environment.staging:
        return 'staging';
      case Environment.prod:
        return 'prod';
    }
  }

  static Environment fromString(String value) {
    switch (value.toLowerCase()) {
      case 'dev':
        return Environment.dev;
      case 'staging':
        return Environment.staging;
      case 'prod':
        return Environment.prod;
      default:
        throw ArgumentError('Invalid ENV value: $value. Must be one of: dev, staging, prod');
    }
  }
}