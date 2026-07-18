import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wts_sdk/wts_sdk.dart';
import 'package:wts_sdk/src/messages.g.dart' as pigeon;

BasicMessageChannel<Object?> _testSessionChannel(String method) =>
    BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.wts_sdk.WtsHostApi.$method',
      pigeon.WtsHostApi.pigeonChannelCodec,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePlatform platform;

  setUp(() {
    platform = FakePlatform();
    WtsSdk.platform = platform;
  });

  test('revenue normalizes currency at the platform boundary', () {
    expect(WtsRevenue(amount: '12.50', currency: 'try').currency, 'TRY');
  });

  test('handle preserves typed scalar parameters', () async {
    final WtsDeepLink link =
        await WtsSdk.handle(Uri.parse('https://demo.links.wts.is/summer'));

    expect(link.linkId, 'link_example');
    expect(link.parameters,
        <String, Object>{'campaign': 'summer', 'featured': true});
  });

  test('track rejects unsupported property values before native invocation',
      () async {
    expect(
      () => WtsSdk.track('purchase',
          properties: <String, Object>{'nested': <String, Object>{}}),
      throwsArgumentError,
    );
    expect(platform.trackCalls, 0);
  });

  test('track sends normalized revenue to the native core', () async {
    await WtsSdk.track(
      'purchase',
      properties: <String, Object>{'order_id': '42'},
      revenue: WtsRevenue(amount: '12.50', currency: 'try'),
    );

    expect(platform.trackCalls, 1);
    expect(platform.revenue?.currency, 'TRY');
  });

  test('screen validates and forwards scalar context to the native core',
      () async {
    await WtsSdk.screen(
      'checkout',
      properties: <String, Object>{'cart_total': 749.90, 'item_count': 3},
    );
    expect(platform.lastScreen, 'checkout');
  });

  test('diagnostics expose the PII-free test device token', () async {
    final WtsExperienceDiagnostics diagnostics =
        await WtsSdk.getExperienceDiagnostics();

    expect(diagnostics.testDeviceToken, 'test-device-token');
  });

  test('forwards a canonical pairing URL unchanged after trimming', () async {
    const String canonicalPairing =
        'https://notiword.wts.is/_wts/test/pair?pairing=pairing-token';

    final WtsTestSessionJoinResult joined = await WtsSdk.joinTestSession(
      '  $canonicalPairing  ',
    );

    expect(platform.lastPairing, canonicalPairing);
    expect(joined, isA<WtsTestSessionJoinResult>());
    expect(joined.joined, isTrue);
    expect(joined.sessionId, 'test-session-id');
    expect(joined.checks.single.key, 'sdk_version');
  });

  test('forwards diagnostics and preserves the native session state', () async {
    final WtsTestSessionDiagnostics diagnostics =
        await WtsSdk.getTestSessionDiagnostics();

    expect(platform.diagnosticsRequests, 1);
    expect(diagnostics.joined, isTrue);
    expect(diagnostics.compatible, isTrue);
    expect(diagnostics.pendingSignals, 2);
    expect(diagnostics.lastErrorCode, 'TEST_SESSION_RETRYING');
    expect(diagnostics.expiresAt, DateTime.utc(2026, 7, 18, 12));
  });

  test('forwards a URL probe and keeps typed resolved link parameters',
      () async {
    final Uri url = Uri.parse('https://notiword.wts.is/checkout?ignored=true');

    final WtsTestSessionProbeResult result =
        await WtsSdk.probeTestSessionUrl(url);

    expect(platform.lastProbeUrl, url.toString());
    expect(result.match, isTrue);
    expect(result.originalUrl, url);
    expect(result.fallbackUrl, Uri.parse('https://personaleak.com/checkout'));
    expect(result.link?.id, 'link_checkout');
    expect(result.link?.path, '/checkout');
    expect(result.link?.parameters,
        <String, Object?>{'coupon': 'summer', 'member': true, 'sourceId': 42});
  });

  test(
      'requires an explicit post-decision test interaction and keeps normal Experience controls separate',
      () async {
    expect(await WtsSdk.reportTestSessionExperienceInteraction('impression'),
        isFalse);

    await WtsSdk.presentNextExperience();
    await WtsSdk.dismissCurrentExperience();
    expect(platform.testExperienceInteractions, isEmpty);

    final WtsTestSessionProbeRunResult probes =
        await WtsSdk.runTestSessionProbes();

    expect(probes.experienceDecision?.outcome, 'ready');
    expect(probes.experienceDecision?.testGrant,
        <String, Object?>{'grant': 'test-grant'});
    expect(probes.experienceDecision?.decision,
        <String, Object?>{'campaignId': 'campaign_checkout'});
    expect(await WtsSdk.reportTestSessionExperienceInteraction('impression'),
        isTrue);
    expect(platform.testExperienceInteractions, <String>['impression']);
  });

  test(
      'rejects unsupported test Experience interactions before native forwarding',
      () {
    expect(
      () => WtsSdk.reportTestSessionExperienceInteraction('dismiss'),
      throwsArgumentError,
    );
    expect(platform.testExperienceInteractions, isEmpty);
  });

  test('Pigeon bridge maps the complete test-session surface', () async {
    const String canonicalPairing =
        'https://notiword.wts.is/_wts/test/pair?pairing=pairing-token';
    final dynamic messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockDecodedMessageHandler<Object?>(
      _testSessionChannel('joinTestSession'),
      (Object? message) async {
        expect(message, <Object?>[canonicalPairing]);
        return <Object?>[
          pigeon.WtsTestSessionJoinData(
            accepted: true,
            joined: true,
            compatible: true,
            checks: <pigeon.WtsTestSessionCheckData>[
              pigeon.WtsTestSessionCheckData(
                  key: 'sdk_version', status: 'passed'),
            ],
            sessionId: 'test-session-id',
            expiresAt: '2026-07-18T12:00:00.000Z',
          ),
        ];
      },
    );
    messenger.setMockDecodedMessageHandler<Object?>(
      _testSessionChannel('getTestSessionDiagnostics'),
      (Object? message) async {
        expect(message, isNull);
        return <Object?>[
          pigeon.WtsTestSessionDiagnosticsData(
            joined: true,
            compatible: true,
            checks: <pigeon.WtsTestSessionCheckData>[
              pigeon.WtsTestSessionCheckData(
                key: 'sdk_version',
                status: 'passed',
              ),
            ],
            pendingSignals: 2,
            lastErrorCode: 'TEST_SESSION_RETRYING',
          ),
        ];
      },
    );
    messenger.setMockDecodedMessageHandler<Object?>(
      _testSessionChannel('probeTestSessionUrl'),
      (Object? message) async {
        expect(message, <Object?>['https://notiword.wts.is/checkout']);
        return <Object?>[
          pigeon.WtsTestSessionProbeData(
            match: true,
            status: 'active',
            code: 'OK',
            originalUrl: 'https://notiword.wts.is/checkout',
            fallbackUrl: 'https://personaleak.com/checkout',
            link: pigeon.WtsTestSessionProbeLinkData(
              id: 'link_checkout',
              path: '/checkout',
              parametersJson: '{"coupon":"summer","member":true,"sourceId":42}',
            ),
          ),
        ];
      },
    );
    messenger.setMockDecodedMessageHandler<Object?>(
      _testSessionChannel('runTestSessionProbes'),
      (Object? message) async {
        expect(message, isNull);
        return <Object?>[
          pigeon.WtsTestSessionProbeRunData(
            accepted: true,
            emitted: <String>['identity_recorded', 'event_recorded'],
            skipped: <String>[],
            pendingSignals: 0,
            experienceDecisionJson:
                '{"outcome":"ready","testGrant":{"grant":"test-grant"},"decision":{"campaignId":"campaign_checkout"}}',
          ),
        ];
      },
    );
    messenger.setMockDecodedMessageHandler<Object?>(
      _testSessionChannel('reportTestSessionExperienceInteraction'),
      (Object? message) async {
        expect(message, <Object?>['impression']);
        return <Object?>[true];
      },
    );
    WtsSdk.platform = PigeonWtsPlatform();

    final WtsTestSessionJoinResult joined =
        await WtsSdk.joinTestSession('  $canonicalPairing  ');
    final WtsTestSessionDiagnostics diagnostics =
        await WtsSdk.getTestSessionDiagnostics();
    final WtsTestSessionProbeResult probe = await WtsSdk.probeTestSessionUrl(
      Uri.parse('https://notiword.wts.is/checkout'),
    );
    final WtsTestSessionProbeRunResult probes =
        await WtsSdk.runTestSessionProbes();

    expect(joined.expiresAt, DateTime.utc(2026, 7, 18, 12));
    expect(diagnostics.pendingSignals, 2);
    expect(probe.link?.parameters,
        <String, Object?>{'coupon': 'summer', 'member': true, 'sourceId': 42});
    expect(probes.experienceDecision?.outcome, 'ready');
    expect(probes.experienceDecision?.testGrant,
        <String, Object?>{'grant': 'test-grant'});
    expect(await WtsSdk.reportTestSessionExperienceInteraction('impression'),
        isTrue);
  });

  test('Pigeon bridge keeps malformed test decision payloads non-fatal',
      () async {
    final dynamic messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler<Object?>(
      _testSessionChannel('runTestSessionProbes'),
      (Object? message) async => <Object?>[
        pigeon.WtsTestSessionProbeRunData(
          accepted: true,
          emitted: <String>[],
          skipped: <String>[],
          pendingSignals: 0,
          experienceDecisionJson: '{"testGrant":{"grant":"test-grant"}}',
        ),
      ],
    );
    WtsSdk.platform = PigeonWtsPlatform();

    final WtsTestSessionProbeRunResult result =
        await WtsSdk.runTestSessionProbes();

    expect(result.experienceDecision?.outcome, 'unavailable');
    expect(result.experienceDecision?.testGrant,
        <String, Object?>{'grant': 'test-grant'});
  });

  test('handle errors retain the original web fallback URL', () async {
    platform.handleError = PlatformException(code: 'TIMEOUT');
    final Uri url = Uri.parse('https://demo.links.wts.is/summer');

    await expectLater(
      WtsSdk.handle(url),
      throwsA(isA<WtsSdkException>()
          .having((WtsSdkException error) => error.code, 'code', 'TIMEOUT')
          .having((WtsSdkException error) => error.fallbackUrl, 'fallbackUrl',
              url)),
    );
  });

  test('uses the native fallback URL when the operation has no web URL',
      () async {
    platform.configureError = PlatformException(
      code: 'NETWORK_ERROR',
      details: 'https://wts.is/fallback',
    );

    await expectLater(
      WtsSdk.configure(appKey: 'public-app-key'),
      throwsA(isA<WtsSdkException>()
          .having(
              (WtsSdkException error) => error.code, 'code', 'NETWORK_ERROR')
          .having((WtsSdkException error) => error.fallbackUrl, 'fallbackUrl',
              Uri.parse('https://wts.is/fallback'))),
    );
  });

  test('canonical event batch fixture keeps stable rejection fields', () {
    final Map<String, Object?> fixture = jsonDecode(
      File('contracts/v1/fixtures/event-batch-mixed.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final List<Object?> rejected = fixture['rejected']! as List<Object?>;
    final Map<String, Object?> item = rejected.single! as Map<String, Object?>;

    expect(item['code'], 'EVENT_NOT_REGISTERED');
    expect(item['retryable'], isFalse);
  });
}

class FakePlatform implements WtsPlatform {
  int trackCalls = 0;
  int diagnosticsRequests = 0;
  WtsRevenue? revenue;
  Object? handleError;
  Object? configureError;
  String? lastScreen;
  String? lastPairing;
  String? lastProbeUrl;
  bool _testExperienceDecisionReady = false;
  final List<String> testExperienceInteractions = <String>[];

  @override
  Future<void> configure(
    String appKey,
    String? apiBaseUrl,
    String? collectorBaseUrl,
    WtsExperienceOptions experiences,
  ) async {
    if (configureError case final Object error) throw error;
  }

  @override
  Future<void> flush() async {}

  @override
  Future<WtsDeepLink?> getDeferredDeepLink() async => null;

  @override
  Future<void> setProfileConsent(bool granted) async {}

  @override
  Future<void> identify(
      String externalUserId, Map<String, Object> attributes) async {}

  @override
  Future<void> updateUser(WtsUserUpdate update) async {}

  @override
  Future<void> setReportedAttribution(
      WtsReportedAttribution attribution) async {}

  @override
  Future<void> resetIdentity() async {}

  @override
  Future<WtsDeepLink> handle(String url) async {
    if (handleError case final Object error) throw error;
    return const WtsDeepLink(
      path: '/products/123',
      parameters: <String, Object>{'campaign': 'summer', 'featured': true},
      linkId: 'link_example',
      attributionId: 'attribution_example',
      isDeferred: false,
    );
  }

  @override
  Future<void> track(
    String eventKey,
    Map<String, Object> properties,
    WtsRevenue? revenue,
    String? linkId,
  ) async {
    trackCalls += 1;
    this.revenue = revenue;
  }

  @override
  Future<void> screen(String name, Map<String, Object> properties) async {
    lastScreen = name;
  }

  @override
  Future<void> setExperienceConsent(WtsExperienceConsent consent) async {}

  @override
  Future<bool> presentNextExperience() async => false;

  @override
  Future<bool> dismissCurrentExperience() async => false;

  @override
  Future<WtsExperienceDiagnostics> getExperienceDiagnostics() async =>
      const WtsExperienceDiagnostics(
        enabled: false,
        consent: WtsExperienceConsent.pending,
        queued: 0,
        presenting: false,
        testDeviceToken: 'test-device-token',
      );

  @override
  Future<WtsTestSessionJoinResult> joinTestSession(String pairing) async {
    lastPairing = pairing;
    return WtsTestSessionJoinResult(
      accepted: true,
      joined: true,
      compatible: true,
      checks: const <WtsTestSessionCheck>[
        WtsTestSessionCheck(key: 'sdk_version', status: 'passed'),
      ],
      sessionId: 'test-session-id',
    );
  }

  @override
  Future<bool> leaveTestSession() async => true;

  @override
  Future<WtsTestSessionDiagnostics> getTestSessionDiagnostics() async {
    diagnosticsRequests += 1;
    return WtsTestSessionDiagnostics(
      joined: true,
      compatible: true,
      checks: const <WtsTestSessionCheck>[
        WtsTestSessionCheck(key: 'sdk_version', status: 'passed'),
      ],
      pendingSignals: 2,
      expiresAt: DateTime.utc(2026, 7, 18, 12),
      lastErrorCode: 'TEST_SESSION_RETRYING',
    );
  }

  @override
  Future<WtsTestSessionProbeResult> probeTestSessionUrl(String url) async {
    lastProbeUrl = url;
    return WtsTestSessionProbeResult(
      match: true,
      status: 'active',
      code: 'OK',
      originalUrl: Uri.parse(url),
      fallbackUrl: Uri.parse('https://personaleak.com/checkout'),
      link: const WtsTestSessionProbeLink(
        id: 'link_checkout',
        path: '/checkout',
        parameters: <String, Object?>{
          'coupon': 'summer',
          'member': true,
          'sourceId': 42,
        },
      ),
    );
  }

  @override
  Future<WtsTestSessionProbeRunResult> runTestSessionProbes() async {
    _testExperienceDecisionReady = true;
    return const WtsTestSessionProbeRunResult(
      accepted: true,
      emitted: <String>['identity_recorded', 'event_recorded'],
      skipped: <String>[],
      pendingSignals: 0,
      experienceDecision: WtsTestSessionExperienceDecision(
        outcome: 'ready',
        reason: null,
        testGrant: <String, Object?>{'grant': 'test-grant'},
        decision: <String, Object?>{'campaignId': 'campaign_checkout'},
      ),
    );
  }

  @override
  Future<bool> reportTestSessionExperienceInteraction(
      String interaction) async {
    if (!_testExperienceDecisionReady) return false;
    testExperienceInteractions.add(interaction);
    return true;
  }
}
