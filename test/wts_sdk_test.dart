import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wts_sdk/wts_sdk.dart';

void main() {
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
  WtsRevenue? revenue;
  Object? handleError;
  Object? configureError;
  String? lastScreen;

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
}
