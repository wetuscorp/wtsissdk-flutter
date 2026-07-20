## 0.5.0-alpha.1

- Replaced the separate analytics/profile and Experiences consent controls with
  the persisted `pending`, `granted`, and `denied` unified consent model.
- Added automatic Experiences Protocol V2 delivery through the native Android
  and Swift renderers, including diagnostics and handled/unhandled advanced
  action outcomes.
- Pins Android `co.wetus:wts-sdk:0.5.0-alpha.1` and iOS `WtsSDK
  0.5.0-alpha.1` exactly for the coordinated release.
- Clears legacy 0.4 wrapper state on first launch and keeps analytics,
  identity, attribution, Experiences, and test-session storage/network closed
  until consent is granted.

## 0.4.0-alpha.1

- Pins Android `co.wetus:wts-sdk:0.4.0-alpha.1` and iOS `WtsSDK
  0.4.0-alpha.1` exactly; keep the Flutter wrapper and both native cores on
  this matching version.
- Added verified Experiences manifest delivery: the wrapper passes a pinned
  Ed25519 public-key ring to the native cores, which verify the signed payload
  before parsing it. Unverified outer manifest content is not used.
- Replaced the ambiguous manual-presentation callback with an opaque
  presentation handle and explicit render, impression, action, and dismissal
  lifecycle acknowledgements.
- Removed delivery correlation identifiers from public Experience payloads;
  manual lifecycle correlation remains internal to the opaque handle.
- Preserved SDK Test Session V1 pairing, probes, diagnostics, and isolated
  test-only Experience reporting.

## 0.3.0-alpha.1

- Wrapped Mobile Protocol V3 built-in screen tracking from both native cores.
- Added explicitly opt-in contextual and personalized Experiences consent.
- Added native automatic/manual presentation and diagnostics through generated Pigeon channels.
- Kept delivery, persistence, safe actions and impression measurement in the Swift/Kotlin cores.
- Added SDK Test Session V1 pairing, diagnostics, isolated probes, and explicit
  test-only Experience impression/action reporting through Pigeon.

## 0.2.0-alpha.1

- Added consent-gated cross-SDK identity, managed user attributes, reported attribution, and identity reset through the native Swift and Android cores.
- Identity mutations use the native persistent queue and are flushed before analytics events.
- Normalized native failures into stable cross-platform `WtsSdkException` codes.

## 0.1.0-alpha.1

- Initial public alpha wrapping the official Swift and Android native cores through generated Pigeon channels.
