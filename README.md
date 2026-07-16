# wts_sdk

Official Flutter wrapper for the wts.is Swift and Android SDKs. Generated Pigeon channels preserve scalar parameter types and revenue precision; networking, install identity and event persistence stay in the native cores.

> `0.2.0-alpha.1` · Mobile Protocol V2 + Identity V1 · Flutter 3.35+ · iOS 15+ · Android API 23+

## Install

```yaml
dependencies:
  wts_sdk: 0.2.0-alpha.1
```

## Configure and handle links

```dart
await WtsSdk.configure(appKey: 'YOUR_PUBLIC_APP_KEY');

Future<void> handle(Uri uri) async {
  try {
    final link = await WtsSdk.handle(uri);
    if (allowedRoutes.contains(link.path)) {
      router.go(link.path, extra: link.parameters);
    }
  } on WtsSdkException catch (error) {
    if (error.fallbackUrl != null) await launchUrl(error.fallbackUrl!);
  }
}
```

Connect `handle` to your app lifecycle (`app_links`, Router, or the lifecycle package you already use). Configure Associated Domains on iOS and an auto-verified App Link intent filter on Android.

## Deferred and events

```dart
final deferred = await WtsSdk.getDeferredDeepLink(); // Android only in V1

await WtsSdk.track(
  'purchase_completed',
  properties: {'plan': 'pro', 'trial': false},
  revenue: WtsRevenue(amount: '49.90', currency: 'TRY'),
);
await WtsSdk.flush(); // optional
```

iOS returns `null` for deferred resolution. The SDK does not navigate automatically and does not use IDFA, GAID, pasteboard attribution, or fingerprinting. Event keys/properties must be registered in the dashboard.

## Consent-aware identity

Profile identity is disabled until the host application provides its own consent decision. Anonymous link handling and analytics keep their existing behavior.

```dart
await WtsSdk.setProfileConsent(true);

await WtsSdk.identify(
  'customer_1842',
  attributes: {
    'email': 'user@example.com',
    'plan': 'enterprise',
    'country': 'TR',
    'subscribed': true,
  },
);

await WtsSdk.updateUser(
  const WtsUserUpdate(
    set: {'plan': 'business'},
    setOnce: {'signup_channel': 'partner'},
    unset: ['temporary_segment'],
    increment: {'lifetime_orders': 1},
  ),
);

await WtsSdk.setReportedAttribution(
  const WtsReportedAttribution(
    source: 'newsletter',
    medium: 'email',
    campaign: 'summer_2026',
    externalRef: 'mailing-482',
  ),
);

// On logout: removes the profile binding and starts a fresh anonymous/session identity.
await WtsSdk.resetIdentity();
```

Use an opaque, stable internal customer ID as `externalUserId`; send email, phone, and name as attributes. `resetIdentity()` preserves the native install UUID used by the underlying mobile SDK.

See the runnable `example`, [security policy](SECURITY.md), and [support policy](SUPPORT.md). Full documentation: https://wts.is/docs/sdk/flutter
