import 'package:pulseboard_analytics/pulseboard_analytics.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppAnalytics.initialize(
    AnalyticsConfig(
      dsn: 'https://wk_example_key@pulseboard.example.com/proj_123/production',
      debug: true,
    ),
  );

  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Pulseboard SDK Example',
      home: ExamplePage(),
    );
  }
}

class ExamplePage extends StatelessWidget {
  const ExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pulseboard SDK Example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Button(
            label: 'Track Event',
            onPressed: () {
              AppAnalytics.instance.track(
                'button_pressed',
                properties: {'button_id': 'example_1'},
              );
            },
          ),
          _Button(
            label: 'Identify User',
            onPressed: () {
              AppAnalytics.instance.identify('user_42');
            },
          ),
          _Button(
            label: 'Set User Property',
            onPressed: () {
              AppAnalytics.instance.setUserProperty('plan', 'premium');
            },
          ),
          _Button(
            label: 'Set User Property Once',
            onPressed: () {
              AppAnalytics.instance
                  .setUserPropertyOnce('first_seen', DateTime.now().toIso8601String());
            },
          ),
          _Button(
            label: 'Increment Property',
            onPressed: () {
              AppAnalytics.instance.incrementUserProperty('login_count', 1);
            },
          ),
          _Button(
            label: 'Unset Property',
            onPressed: () {
              AppAnalytics.instance.unsetUserProperty('temp_flag');
            },
          ),
          _Button(
            label: 'Start & Stop Trace',
            onPressed: () async {
              final trace = AppAnalytics.instance.startTrace('api_call');
              trace.putAttribute('endpoint', '/users');
              await Future<void>.delayed(const Duration(milliseconds: 200));
              trace.stop();
            },
          ),
          _Button(
            label: 'Add Breadcrumb',
            onPressed: () {
              AppAnalytics.instance.addBreadcrumb(
                type: 'navigation',
                message: 'Opened settings screen',
              );
            },
          ),
          _Button(
            label: 'Flush',
            onPressed: () async {
              await AppAnalytics.instance.flush();
            },
          ),
          _Button(
            label: 'Opt Out',
            onPressed: () => AppAnalytics.instance.optOut(),
          ),
          _Button(
            label: 'Opt In',
            onPressed: () => AppAnalytics.instance.optIn(),
          ),
          _Button(
            label: 'Grant Consent',
            onPressed: () => AppAnalytics.instance.grantConsent(),
          ),
          _Button(
            label: 'Revoke Consent',
            onPressed: () => AppAnalytics.instance.revokeConsent(),
          ),
          _Button(
            label: 'Reset',
            onPressed: () async {
              await AppAnalytics.instance.reset();
            },
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _Button({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
