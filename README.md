# wts.is Flutter SDK

Official Flutter SDK for deep links, analytics, identity, and deployless native Experiences.

> `0.5.0-alpha.1` · exact native pins: Android `co.wetus:wts-sdk:0.5.0-alpha.1`, iOS `WtsSDK 0.5.0-alpha.1` · Mobile V4 · Experiences V2 · Test Session V2

## Install

```yaml
dependencies:
  wts_sdk: 0.5.0-alpha.1
```

## One-time integration

Configure the public app/source key once. The host owns the consent UI; the SDK persists and restores the unified decision.

```dart
await WtsSdk.configure(appKey: 'YOUR_PUBLIC_APP_KEY');

switch (await WtsSdk.getConsentState()) {
  case WtsConsentState.pending:
    await showConsentUi();
  case WtsConsentState.granted:
  case WtsConsentState.denied:
}

await WtsSdk.setConsent(WtsConsentState.granted); // or denied
```

`pending` and `denied` disable event, identity, attribution, Experience, and test-session storage/network. A data-minimized direct functional link resolve is the only exception. Denial clears local data and closes an active Experience. The `0.5` namespace starts at `pending`; `0.4` state is not migrated.

## Deployless Experiences

Continue sending the events already integrated in the application. Campaigns select panel-defined events; there is no campaign key, manifest key, client allowlist, Experience init block, renderer mode, or manual presentation API.

```dart
await WtsSdk.track(
  'purchase_completed',
  properties: {'plan': 'pro'},
  revenue: WtsRevenue(amount: '49.90', currency: 'TRY'),
);
await WtsSdk.screen('checkout', properties: {'item_count': 3});
```

The exact-pinned native cores verify the root-signed online keyset and source-bound manifest, refresh foreground config within 60 seconds, queue matching campaigns by priority, and render native modal or bottom-sheet Experiences automatically. Expired offline config fails closed.

Advanced internal-route and custom-callback actions can install an optional synchronous handler:

```dart
final unsubscribe = WtsSdk.onExperienceAction((experience, action) {
  if (action.type == 'OPEN_INTERNAL_ROUTE' && action.target != null) {
    router.open(action.target!);
    return true;
  }
  return false;
});
```

Return `true` only after handling the action. Missing, throwing, or `false` handlers report `unhandled` and keep the Experience open. Call `dismissCurrentExperience()` for the emergency host-side close control and `getExperienceDiagnostics()` for support diagnostics.

## Deep links and identity

```dart
final link = await WtsSdk.handle(incomingUri);
if (allowedRoutes.contains(link.path)) router.open(link.path);

await WtsSdk.identify('customer_1842', attributes: {'plan': 'enterprise'});
```

Before grant, `handle` performs functional resolution without creating install identity or attribution. Normal attribution and deferred resolution start after grant. Once `identify` is accepted, Experience decisions automatically switch from contextual to personalized mode.

## SDK Test Session V2

After grant, route the dashboard pairing URL through `joinTestSession` before normal `handle`, then call `runTestSessionProbes()`. Test Experiences use the native automatic renderer in an isolated queue and never enter the production queue.

See the [example](example), [security policy](SECURITY.md), and [support policy](SUPPORT.md). Full documentation: https://wts.is/en/resources/docs/sdk-flutter
