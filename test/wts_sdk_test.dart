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

  test('handle errors retain the original web fallback URL', () async {
    platform.handleError = PlatformException(code: 'timeout');
    final Uri url = Uri.parse('https://demo.links.wts.is/summer');

    await expectLater(
      WtsSdk.handle(url),
      throwsA(isA<WtsSdkException>().having(
          (WtsSdkException error) => error.fallbackUrl, 'fallbackUrl', url)),
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

  @override
  Future<void> configure(String appKey, String? apiBaseUrl) async {}

  @override
  Future<void> flush() async {}

  @override
  Future<WtsDeepLink?> getDeferredDeepLink() async => null;

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
}
