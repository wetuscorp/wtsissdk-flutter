## 0.2.0-alpha.1

- Added consent-gated cross-SDK identity, managed user attributes, reported attribution, and identity reset through the native Swift and Android cores.
- Identity mutations use the native persistent queue and are flushed before analytics events.
- Normalized native failures into stable cross-platform `WtsSdkException` codes.

## 0.1.0-alpha.1

- Initial public alpha wrapping the official Swift and Android native cores through generated Pigeon channels.
