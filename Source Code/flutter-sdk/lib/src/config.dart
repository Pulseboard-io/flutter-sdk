/// SDK configuration with DSN parsing.
///
/// DSN format: `https://<public_key>@<host>/<project-id>/<environment>`
class AnalyticsConfig {
  /// The full DSN string.
  final String dsn;

  /// Parsed API endpoint (e.g. `https://pulseboard.example.com`).
  final String endpoint;

  /// Parsed public key used as Bearer token.
  final String publicKey;

  /// Parsed project ID.
  final String projectId;

  /// Parsed environment name.
  final String environment;

  /// Maximum events per batch (max 500 per API).
  final int flushAt;

  /// Flush interval in seconds.
  final int flushIntervalSeconds;

  /// Enable debug logging.
  final bool debug;

  /// Sampling rate (0.0 to 1.0). 1.0 = send all events.
  final double sampleRate;

  /// Maximum retry attempts for failed requests.
  final int maxRetries;

  /// Session timeout in minutes (for resume detection).
  final int sessionTimeoutMinutes;

  /// Maximum breadcrumbs to keep for crash reports.
  final int maxBreadcrumbs;

  /// Maximum events to persist offline.
  final int maxPersistedEvents;

  AnalyticsConfig._({
    required this.dsn,
    required this.endpoint,
    required this.publicKey,
    required this.projectId,
    required this.environment,
    this.flushAt = 20,
    this.flushIntervalSeconds = 30,
    this.debug = false,
    this.sampleRate = 1.0,
    this.maxRetries = 3,
    this.sessionTimeoutMinutes = 5,
    this.maxBreadcrumbs = 20,
    this.maxPersistedEvents = 1000,
  });

  /// Create a config by parsing a DSN string.
  ///
  /// DSN format: `https://<public_key>@<host>/<project-id>/<environment>`
  ///
  /// Throws [FormatException] if the DSN is invalid.
  factory AnalyticsConfig({
    required String dsn,
    int flushAt = 20,
    int flushIntervalSeconds = 30,
    bool debug = false,
    double sampleRate = 1.0,
    int maxRetries = 3,
    int sessionTimeoutMinutes = 5,
    int maxBreadcrumbs = 20,
    int maxPersistedEvents = 1000,
  }) {
    final parsed = _parseDsn(dsn);
    return AnalyticsConfig._(
      dsn: dsn,
      endpoint: parsed.endpoint,
      publicKey: parsed.publicKey,
      projectId: parsed.projectId,
      environment: parsed.environment,
      flushAt: flushAt,
      flushIntervalSeconds: flushIntervalSeconds,
      debug: debug,
      sampleRate: sampleRate.clamp(0.0, 1.0),
      maxRetries: maxRetries,
      sessionTimeoutMinutes: sessionTimeoutMinutes,
      maxBreadcrumbs: maxBreadcrumbs,
      maxPersistedEvents: maxPersistedEvents,
    );
  }

  static _DsnParts _parseDsn(String dsn) {
    final uri = Uri.tryParse(dsn);
    if (uri == null) {
      throw FormatException('Invalid DSN: cannot parse URI', dsn);
    }

    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw FormatException('Invalid DSN: scheme must be https or http', dsn);
    }

    final publicKey = uri.userInfo;
    if (publicKey.isEmpty) {
      throw FormatException('Invalid DSN: missing public key', dsn);
    }

    final host = uri.host;
    if (host.isEmpty) {
      throw FormatException('Invalid DSN: missing host', dsn);
    }

    final pathSegments =
        uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (pathSegments.length < 2) {
      throw FormatException(
        'Invalid DSN: path must contain /<project-id>/<environment>',
        dsn,
      );
    }

    final projectId = pathSegments[0];
    final environment = pathSegments[1];

    final port = uri.hasPort ? ':${uri.port}' : '';
    final endpoint = '${uri.scheme}://$host$port';

    return _DsnParts(
      endpoint: endpoint,
      publicKey: publicKey,
      projectId: projectId,
      environment: environment,
    );
  }
}

class _DsnParts {
  final String endpoint;
  final String publicKey;
  final String projectId;
  final String environment;

  const _DsnParts({
    required this.endpoint,
    required this.publicKey,
    required this.projectId,
    required this.environment,
  });
}
