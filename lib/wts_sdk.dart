library;

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import 'src/messages.g.dart';

typedef WtsScalar = Object;

class WtsDeepLink {
  const WtsDeepLink({
    required this.path,
    required this.parameters,
    required this.linkId,
    required this.attributionId,
    required this.isDeferred,
  });

  final String path;
  final Map<String, Object> parameters;
  final String linkId;
  final String attributionId;
  final bool isDeferred;
}

class WtsRevenue {
  WtsRevenue({required this.amount, required String currency})
      : currency = currency.toUpperCase() {
    if (!RegExp(r'^-?\d{1,12}(?:\.\d{1,6})?$').hasMatch(amount)) {
      throw ArgumentError.value(amount, 'amount', 'Expected a decimal string.');
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(this.currency)) {
      throw ArgumentError.value(
          currency, 'currency', 'Expected an ISO-4217 code.');
    }
  }

  final String amount;
  final String currency;
}

class WtsSdkException implements Exception {
  const WtsSdkException(this.code, this.message, {this.fallbackUrl});
  final String code;
  final String message;
  final Uri? fallbackUrl;

  @override
  String toString() => 'WtsSdkException($code, $message)';
}

class WtsSdk {
  WtsSdk._();
  static WtsPlatform _platform = PigeonWtsPlatform();

  @visibleForTesting
  static set platform(WtsPlatform value) => _platform = value;

  static Future<void> configure({required String appKey, String? apiBaseUrl}) =>
      _guard(() => _platform.configure(appKey, apiBaseUrl));

  static Future<WtsDeepLink> handle(Uri uri) =>
      _guard(() => _platform.handle(uri.toString()), fallbackUrl: uri);

  static Future<WtsDeepLink?> getDeferredDeepLink() =>
      _guard(_platform.getDeferredDeepLink);

  static Future<void> track(
    String eventKey, {
    Map<String, Object> properties = const {},
    WtsRevenue? revenue,
    String? linkId,
  }) {
    _validateProperties(properties);
    return _guard(() => _platform.track(eventKey, properties, revenue, linkId));
  }

  static Future<void> flush() => _guard(_platform.flush);

  static Future<T> _guard<T>(
    Future<T> Function() operation, {
    Uri? fallbackUrl,
  }) async {
    try {
      return await operation();
    } on PlatformException catch (error) {
      throw WtsSdkException(
        error.code,
        error.message ?? 'Native SDK error.',
        fallbackUrl: fallbackUrl,
      );
    }
  }

  static void _validateProperties(Map<String, Object> properties) {
    if (properties.length > 20) {
      throw ArgumentError.value(
          properties, 'properties', 'At most 20 properties are supported.');
    }
    for (final MapEntry<String, Object> entry in properties.entries) {
      final Object value = entry.value;
      if (value is! String && value is! num && value is! bool) {
        throw ArgumentError.value(
            value, entry.key, 'Expected String, number, or bool.');
      }
      if (value is String && value.length > 512) {
        throw ArgumentError.value(
            value, entry.key, 'String values cannot exceed 512 characters.');
      }
    }
  }
}

abstract interface class WtsPlatform {
  Future<void> configure(String appKey, String? apiBaseUrl);
  Future<WtsDeepLink> handle(String url);
  Future<WtsDeepLink?> getDeferredDeepLink();
  Future<void> track(
    String eventKey,
    Map<String, Object> properties,
    WtsRevenue? revenue,
    String? linkId,
  );
  Future<void> flush();
}

class PigeonWtsPlatform implements WtsPlatform {
  final WtsHostApi _api = WtsHostApi();

  @override
  Future<void> configure(String appKey, String? apiBaseUrl) => _api
      .configure(WtsConfigurationData(appKey: appKey, apiBaseUrl: apiBaseUrl));

  @override
  Future<WtsDeepLink> handle(String url) async =>
      _fromData(await _api.handle(url));

  @override
  Future<WtsDeepLink?> getDeferredDeepLink() async {
    final WtsDeepLinkData? result = await _api.getDeferredDeepLink();
    return result == null ? null : _fromData(result);
  }

  @override
  Future<void> track(
    String eventKey,
    Map<String, Object> properties,
    WtsRevenue? revenue,
    String? linkId,
  ) =>
      _api.track(
        eventKey,
        properties.entries.map(_parameter).toList(growable: false),
        revenue == null
            ? null
            : WtsRevenueData(
                amount: revenue.amount, currency: revenue.currency),
        linkId,
      );

  @override
  Future<void> flush() => _api.flush();

  static WtsDeepLink _fromData(WtsDeepLinkData data) => WtsDeepLink(
        path: data.path,
        parameters: Map<String, Object>.fromEntries(
          data.parameters
              .map((WtsParameterData item) => MapEntry(item.key, _value(item))),
        ),
        linkId: data.linkId,
        attributionId: data.attributionId,
        isDeferred: data.isDeferred,
      );

  static WtsParameterData _parameter(MapEntry<String, Object> entry) {
    final Object value = entry.value;
    if (value is bool) {
      return WtsParameterData(
          key: entry.key, kind: WtsValueKind.boolean, booleanValue: value);
    }
    if (value is num) {
      return WtsParameterData(
        key: entry.key,
        kind: WtsValueKind.number,
        numberValue: value.toDouble(),
      );
    }
    return WtsParameterData(
      key: entry.key,
      kind: WtsValueKind.string,
      stringValue: value as String,
    );
  }

  static Object _value(WtsParameterData item) => switch (item.kind) {
        WtsValueKind.string => item.stringValue!,
        WtsValueKind.number => item.numberValue!,
        WtsValueKind.boolean => item.booleanValue!,
      };
}
