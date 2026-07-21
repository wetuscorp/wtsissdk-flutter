import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wts_sdk/src/messages.g.dart' as pigeon;
import 'package:wts_sdk/wts_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePlatform platform;

  setUp(() {
    platform = FakePlatform();
    WtsSdk.platform = platform;
  });

  test('configure is a one-time source integration without Experience options',
      () async {
    await WtsSdk.configure(
      appKey: 'public-app-key',
      apiBaseUrl: 'https://api.example.test/api/v1',
      collectorBaseUrl: 'https://collect.example.test',
    );

    expect(platform.appKey, 'public-app-key');
    expect(platform.apiBaseUrl, 'https://api.example.test/api/v1');
    expect(platform.collectorBaseUrl, 'https://collect.example.test');
  });

  test('unified consent rejects pending and restores the native decision',
      () async {
    expect(
      () => WtsSdk.setConsent(WtsConsentState.pending),
      throwsArgumentError,
    );
    await WtsSdk.setConsent(WtsConsentState.granted);

    expect(platform.consent, WtsConsentState.granted);
    expect(await WtsSdk.getConsentState(), WtsConsentState.granted);
  });

  test('functional deep links may omit attribution identifiers', () async {
    final WtsDeepLink link =
        await WtsSdk.handle(Uri.parse('https://demo.wts.is/checkout'));

    expect(link.path, '/checkout');
    expect(link.linkId, isNull);
    expect(link.attributionId, isNull);
  });

  test('existing event and screen APIs remain the campaign trigger surface',
      () async {
    await WtsSdk.track(
      'purchase_completed',
      properties: <String, Object>{'plan': 'pro'},
      revenue: WtsRevenue(amount: '49.90', currency: 'try'),
    );
    await WtsSdk.screen(
      'checkout',
      properties: <String, Object>{'item_count': 3},
    );

    expect(platform.eventKey, 'purchase_completed');
    expect(platform.revenue?.currency, 'TRY');
    expect(platform.screenName, 'checkout');
  });

  test('advanced action callback returns handled to the native renderer',
      () async {
    WtsSdk.platform = PigeonWtsPlatform();
    final WtsUnsubscribe unsubscribe = WtsSdk.onExperienceAction(
      (WtsExperience experience, WtsExperienceAction action) =>
          experience.campaignId == 'campaign-checkout' &&
          action.type == 'OPEN_INTERNAL_ROUTE',
    );
    final dynamic messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final Completer<ByteData?> response = Completer<ByteData?>();

    await messenger.handlePlatformMessage(
      'dev.flutter.pigeon.wts_sdk.WtsFlutterApi.onExperienceAction',
      pigeon.WtsFlutterApi.pigeonChannelCodec.encodeMessage(<Object?>[
        pigeon.WtsExperienceData(
          campaignId: 'campaign-checkout',
          campaignVersionId: 'version-1',
          assignmentId: 'assignment-1',
          variantId: 'variant-a',
          placement: 'modal',
          priority: 10,
          translations: <pigeon.WtsExperienceTranslationData>[],
          closeable: true,
          themePreset: 'default',
          delaySeconds: 0,
        ),
        pigeon.WtsExperienceActionData(
          id: 'open-checkout',
          label: 'Continue',
          type: 'OPEN_INTERNAL_ROUTE',
          target: '/checkout',
        ),
      ]),
      response.complete,
    );

    final Object? decoded = pigeon.WtsFlutterApi.pigeonChannelCodec
        .decodeMessage(await response.future);
    expect(decoded, <Object?>[true]);
    unsubscribe();
  });

  test('advanced action is unhandled when no handler accepts it', () async {
    WtsSdk.platform = PigeonWtsPlatform();
    final dynamic messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final Completer<ByteData?> response = Completer<ByteData?>();

    await messenger.handlePlatformMessage(
      'dev.flutter.pigeon.wts_sdk.WtsFlutterApi.onExperienceAction',
      pigeon.WtsFlutterApi.pigeonChannelCodec.encodeMessage(<Object?>[
        pigeon.WtsExperienceData(
          campaignId: 'campaign-unhandled',
          campaignVersionId: 'version-1',
          assignmentId: 'assignment-1',
          variantId: 'variant-a',
          placement: 'modal',
          priority: 1,
          translations: <pigeon.WtsExperienceTranslationData>[],
          closeable: true,
          themePreset: 'default',
          delaySeconds: 0,
        ),
        pigeon.WtsExperienceActionData(
          id: 'custom',
          label: 'Run',
          type: 'CUSTOM_CALLBACK',
          target: 'missing-handler',
        ),
      ]),
      response.complete,
    );

    final Object? decoded = pigeon.WtsFlutterApi.pigeonChannelCodec
        .decodeMessage(await response.future);
    expect(decoded, <Object?>[false]);
  });

  test('diagnostics expose unified consent and emergency dismissal', () async {
    final WtsExperienceDiagnostics diagnostics =
        await WtsSdk.getExperienceDiagnostics();

    expect(diagnostics.consent, WtsConsentState.pending);
    expect(diagnostics.testDeviceToken, 'test-device-token');
    expect(await WtsSdk.dismissCurrentExperience(), isFalse);
  });

  test(
      'test session remains isolated and requires the native automatic renderer',
      () async {
    final WtsTestSessionJoinResult result =
        await WtsSdk.joinTestSession('pairing-token');
    final WtsTestSessionProbeRunResult probes =
        await WtsSdk.runTestSessionProbes();

    expect(result.joined, isTrue);
    expect(probes.experienceDecision?.outcome, 'ready');
  });
}

class FakePlatform implements WtsPlatform {
  String? appKey;
  String? apiBaseUrl;
  String? collectorBaseUrl;
  String? eventKey;
  String? screenName;
  WtsRevenue? revenue;
  WtsConsentState consent = WtsConsentState.pending;

  @override
  Future<void> configure(
    String appKey,
    String? apiBaseUrl,
    String? collectorBaseUrl,
  ) async {
    this.appKey = appKey;
    this.apiBaseUrl = apiBaseUrl;
    this.collectorBaseUrl = collectorBaseUrl;
  }

  @override
  Future<void> setConsent(WtsConsentState consent) async {
    this.consent = consent;
  }

  @override
  Future<WtsConsentState> getConsentState() async => consent;

  @override
  Future<WtsDeepLink> handle(String url) async => const WtsDeepLink(
        path: '/checkout',
        parameters: <String, Object>{},
        isDeferred: false,
      );

  @override
  Future<WtsDeepLink?> getDeferredDeepLink() async => null;

  @override
  Future<void> track(
    String eventKey,
    Map<String, Object> properties,
    WtsRevenue? revenue,
    String? linkId,
  ) async {
    this.eventKey = eventKey;
    this.revenue = revenue;
  }

  @override
  Future<void> screen(String name, Map<String, Object> properties) async {
    screenName = name;
  }

  @override
  Future<void> identify(
    String externalUserId,
    Map<String, Object> attributes,
  ) async {}

  @override
  Future<void> updateUser(WtsUserUpdate update) async {}

  @override
  Future<void> setReportedAttribution(
      WtsReportedAttribution attribution) async {}

  @override
  Future<void> resetIdentity() async {}

  @override
  Future<bool> dismissCurrentExperience() async => false;

  @override
  Future<WtsExperienceDiagnostics> getExperienceDiagnostics() async =>
      WtsExperienceDiagnostics(
        enabled: consent == WtsConsentState.granted,
        consent: consent,
        queued: 0,
        presenting: false,
        testDeviceToken: 'test-device-token',
      );

  @override
  Future<WtsTestSessionJoinResult> joinTestSession(String pairing) async =>
      const WtsTestSessionJoinResult(
        accepted: true,
        joined: true,
        compatible: true,
        checks: <WtsTestSessionCheck>[],
      );

  @override
  Future<bool> leaveTestSession() async => true;

  @override
  Future<WtsTestSessionDiagnostics> getTestSessionDiagnostics() async =>
      const WtsTestSessionDiagnostics(
        joined: true,
        compatible: true,
        checks: <WtsTestSessionCheck>[],
        pendingSignals: 0,
      );

  @override
  Future<WtsTestSessionProbeResult> probeTestSessionUrl(String url) async =>
      WtsTestSessionProbeResult(
        match: false,
        status: 'inactive',
        code: 'NO_MATCH',
        originalUrl: Uri.parse(url),
        fallbackUrl: Uri.parse(url),
      );

  @override
  Future<WtsTestSessionProbeRunResult> runTestSessionProbes() async =>
      const WtsTestSessionProbeRunResult(
        accepted: true,
        emitted: <String>['experiences'],
        skipped: <String>[],
        pendingSignals: 0,
        experienceDecision: WtsTestSessionExperienceDecision(
          outcome: 'ready',
          reason: null,
          testGrant: <String, Object?>{},
          decision: <String, Object?>{},
        ),
      );

  @override
  Future<void> flush() async {}
}
