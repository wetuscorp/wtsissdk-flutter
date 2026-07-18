# wts_sdk

Official Flutter wrapper for the wts.is Swift and Android SDKs. Generated Pigeon channels preserve scalar parameter types and revenue precision; networking, install identity and event persistence stay in the native cores.

> `0.4.0-alpha.1` release line · Mobile Protocol V3 + Identity V1 + Experiences V1 + SDK Test Session V1 · Flutter 3.35+ · iOS 15+ · Android API 23+

> **Release compatibility:** SDK Test & Validate and Experiences require the
> matching `0.4.0-alpha.1` Flutter package **and** matching published
> Swift/Android core releases. The wrapper deliberately pins those native
> dependencies exactly; release the native cores before this package.

## Install

```yaml
dependencies:
  wts_sdk: <matching-published-version>
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

## Screens and Experiences

Screen views are built-in and do not require a custom-event definition:

```dart
await WtsSdk.screen(
  'checkout',
  properties: {
    'cart_total': 749.90,
    'currency': 'TRY',
    'item_count': 3,
  },
);
```

Experiences is disabled by default. Configure it explicitly before calling a
separate experience-consent API:

```dart
await WtsSdk.configure(
  appKey: 'YOUR_PUBLIC_APP_KEY',
  experiences: const WtsExperienceOptions(
    enabled: true,
    renderMode: WtsExperienceRenderMode.automatic,
    allowedInternalRoutes: {'/checkout', '/account'},
    allowedCallbackKeys: {'apply_offer'},
    allowedDeepLinkHosts: {'go.example.com'},
    allowedDeepLinkSchemes: {'example'},
    allowedWebOrigins: {'https://www.example.com'},
    manifestVerificationKeys: {
      'experience-key-2026-07': 'BASE64_SPKI_DER_ED25519_PUBLIC_KEY',
    },
  ),
);

await WtsSdk.setExperienceConsent(WtsExperienceConsent.contextual);
```

Use `personalized` only after profile consent. `pending` performs no
Experience request and `denied` clears local Experience state. Rendering,
decision networking, persistent interaction retry and visibility-qualified
impressions remain in the official native cores; Flutter does not duplicate
the protocol. Retrieve the public key ring from the authenticated workspace
API, `GET /api/v1/organizations/:organizationId/experiences/manifest-verification-keys`,
and pin the returned `kid` → base64 SPKI DER values in your app configuration.
Never derive these values from, or place, server signing secrets in a client.
The native core ignores the unsigned outer manifest and verifies its signed
payload before it is parsed.

`automatic` rendering stays in the native core. For `manual`, replace the
configuration above with `renderMode: WtsExperienceRenderMode.manual` before
registering a handler. The SDK then emits
typed renderable content and one opaque SDK-issued presentation handle only
when a candidate is available. Delivery identifiers never enter the public
manual payload. The host owns UI presentation and must acknowledge the actual
lifecycle:

```dart
final unsubscribe = WtsSdk.onExperienceAvailable((presentation) async {
  final render = await WtsSdk.acknowledgeExperienceRender(presentation.handle);
  if (!render.accepted) return;

  final result = await showYourExperienceUi(presentation.experience);
  if (result.wasVisibleForOneSecond) {
    await WtsSdk.acknowledgeExperienceImpression(presentation.handle);
  }
  if (result.actionId != null) {
    await WtsSdk.reportExperienceAction(presentation.handle, result.actionId!);
  } else {
    await WtsSdk.dismissExperience(presentation.handle);
  }
});
```

Use `failExperiencePresentation(handle, failureCode)` when the manual renderer
cannot present the candidate. Do not persist or reconstruct presentation
handles. `presentNextExperience()` and `dismissCurrentExperience()` are for
automatic rendering; manual mode never invokes native presentation or emits a
second availability callback.

For an unpublished device test, copy
`(await WtsSdk.getExperienceDiagnostics()).testDeviceToken` into the dashboard
test panel for the matching Mobile App. The random source-scoped token contains
no install, user, or profile identifier, and test traffic is excluded from
customer analytics and usage.

## SDK Test & Validate

SDK Test & Validate is a dashboard-issued, short-lived validation session. It
uses an isolated bounded retry queue; probes never create production events,
identities, attribution, or Experience interactions. Do not hardcode, log, or
persist its pairing URL or token outside the SDK.

The dashboard QR code uses this canonical form:

```text
https://<mobile-app-host>/_wts/test/pair?pairing=<dashboard-issued-token>
```

Recognize that route before your normal deep-link path. Join the test session
first, then return without calling `handle` for the pairing URL:

```dart
Future<void> onIncomingUrl(Uri uri) async {
  if (uri.scheme == 'https' && uri.path == '/_wts/test/pair') {
    final joined = await WtsSdk.joinTestSession(uri.toString());
    showSdkTestChecks(joined.checks);
    return;
  }

  // Normal production behavior stays unchanged.
  final link = await WtsSdk.handle(uri);
  if (allowedRoutes.contains(link.path)) {
    router.go(link.path, extra: link.parameters);
  }
}
```

Use the dashboard-selected plan and inspect its isolated status without
creating analytics:

```dart
final diagnostics = await WtsSdk.getTestSessionDiagnostics();
final probes = await WtsSdk.runTestSessionProbes();

// A ready decision is a test-only, manual preview. It is not delivered to the
// normal Experiences renderer.
if (probes.experienceDecision?.outcome == 'ready') {
  await presentTestExperiencePreview(probes.experienceDecision!);
  await WtsSdk.reportTestSessionExperienceInteraction('impression');
}
```

Report `'action'` only after the corresponding real manual test action. It is
accepted only after the isolated decision is ready; production Experience
lifecycle signals are never copied into this transport. Use
`probeTestSessionUrl(uri)` for an event-free resolver check and
`leaveTestSession()` when the operator finishes. Expiry also clears the
session.

## Consent-aware identity

Profile identity is disabled until the host application provides its own consent decision. Anonymous link handling and analytics keep their existing behavior. Setting consent to `false` queues a server-side profile binding reset through the native core.

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

Use an opaque, stable internal customer ID as `externalUserId`; it is case-sensitive and is not trimmed or normalized. Send email, phone, and name as attributes. `resetIdentity()` preserves the native install UUID used by the underlying mobile SDK.

See the runnable `example`, [security policy](SECURITY.md), and [support policy](SUPPORT.md). Full documentation: https://wts.is/en/resources/docs/sdk-flutter

Native failures are exposed as `WtsSdkException` with stable codes such as
`TIMEOUT`, `NO_MATCH`, and `PROFILE_CONSENT_REQUIRED`.
