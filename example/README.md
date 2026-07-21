# wts.is Flutter example

The example uses `wts_sdk 0.5.0-alpha.1` with exact Android and iOS native core pins at `0.5.0-alpha.1`.

Integrate once with `WtsSdk.configure`, persist a unified `setConsent` decision, and keep sending existing `track` and `screen` events. Experiences are selected remotely and rendered by the native cores automatically.

SDK Test Session V2 pairing must be handled before normal deep-link resolution and requires granted consent. Test Experiences render in an isolated automatic queue; no manual preview or acknowledgement API is required.
