import 'package:flutter/material.dart';
import 'package:wts_sdk/wts_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WtsSdk.configure(appKey: 'replace-with-public-app-key');
  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  String _status = 'No deep link';

  Future<void> _checkDeferred() async {
    final WtsDeepLink? result = await WtsSdk.getDeferredDeepLink();
    if (mounted) {
      setState(() {
        _status = result == null
            ? 'No deferred link'
            : 'Resolved ${result.path}';
      });
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('wts.is SDK')),
      body: Center(child: Text(_status)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _checkDeferred,
        label: const Text('Check deferred'),
      ),
    ),
  );
}
