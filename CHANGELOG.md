> The `0.3.0-alpha.1` source line below is not a pub.dev or native package
> publication claim. SDK Test & Validate requires matching published Flutter,
> Swift, and Android releases.

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
