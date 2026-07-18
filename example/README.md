# wts.is Flutter example

Run this application with the Flutter version declared by the SDK, then replace
the example public app key with a Mobile App key from your wts.is workspace. The
sample deliberately keeps routing application-owned: it receives a URL, asks
the SDK for a validated route, and uses its own route allowlist.

## SDK Test & Validate

The dashboard opens this short-lived pairing URL from its QR code:

```text
https://<mobile-app-host>/_wts/test/pair?pairing=<dashboard-issued-token>
```

Handle it before the normal deep-link method:

```dart
Future<void> onIncomingUrl(Uri uri) async {
  if (uri.scheme == 'https' && uri.path == '/_wts/test/pair') {
    final joined = await WtsSdk.joinTestSession(uri.toString());
    showSdkTestChecks(joined.checks);
    return;
  }

  final link = await WtsSdk.handle(uri);
  routeIfAllowed(link);
}
```

After pairing, render `getTestSessionDiagnostics()` and run
`runTestSessionProbes()`. `probeTestSessionUrl()` verifies a supplied URL
without creating an analytics event. If the result contains a ready
`experienceDecision`, display it only through a manual test preview, then
report its actual impression or action with
`reportTestSessionExperienceInteraction('impression')` or `'action'`.
Finish with `leaveTestSession()`.

The pairing credential must not be logged, stored by the app, or reused. Test
signals use an SDK-owned bounded queue separate from production analytics and
Experiences. These APIs require `wts_sdk 0.4.0-alpha.1` and its matching
Android and iOS native core dependencies at `0.4.0-alpha.1`.
