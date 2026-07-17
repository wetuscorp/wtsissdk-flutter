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

class WtsUserUpdate {
  const WtsUserUpdate({
    this.set = const {},
    this.setOnce = const {},
    this.unset = const [],
    this.increment = const {},
  });

  final Map<String, Object> set;
  final Map<String, Object> setOnce;
  final List<String> unset;
  final Map<String, num> increment;
}

class WtsReportedAttribution {
  const WtsReportedAttribution({
    required this.source,
    this.medium,
    this.campaign,
    this.externalRef,
  });

  final String source;
  final String? medium;
  final String? campaign;
  final String? externalRef;
}

enum WtsExperienceConsent { pending, contextual, personalized, denied }

enum WtsExperienceRenderMode { automatic, manual }

class WtsExperienceOptions {
  const WtsExperienceOptions({
    this.enabled = false,
    this.renderMode = WtsExperienceRenderMode.automatic,
    this.allowedInternalRoutes = const {},
    this.allowedCallbackKeys = const {},
    this.allowedDeepLinkHosts = const {},
    this.allowedDeepLinkSchemes = const {},
    this.allowedWebOrigins = const {},
  });

  final bool enabled;
  final WtsExperienceRenderMode renderMode;
  final Set<String> allowedInternalRoutes;
  final Set<String> allowedCallbackKeys;
  final Set<String> allowedDeepLinkHosts;
  final Set<String> allowedDeepLinkSchemes;
  final Set<String> allowedWebOrigins;
}

class WtsExperienceDiagnostics {
  const WtsExperienceDiagnostics({
    required this.enabled,
    required this.consent,
    required this.queued,
    required this.presenting,
    required this.testDeviceToken,
    this.lastErrorCode,
  });

  final bool enabled;
  final WtsExperienceConsent consent;
  final int queued;
  final bool presenting;
  final String testDeviceToken;
  final String? lastErrorCode;
}

class WtsExperienceAction {
  const WtsExperienceAction({
    required this.id,
    required this.label,
    required this.type,
    this.target,
  });

  final String id;
  final String label;
  final String type;
  final String? target;
}

class WtsExperienceTranslation {
  const WtsExperienceTranslation({
    required this.title,
    required this.description,
    this.primaryAction,
    this.secondaryAction,
  });

  final String title;
  final String description;
  final WtsExperienceAction? primaryAction;
  final WtsExperienceAction? secondaryAction;
}

class WtsExperience {
  const WtsExperience({
    required this.campaignId,
    required this.campaignVersionId,
    required this.assignmentId,
    required this.variantId,
    required this.exposureId,
    required this.placement,
    required this.priority,
    required this.translations,
    required this.closeable,
    required this.themePreset,
    required this.delaySeconds,
    this.autoCloseSeconds,
    this.assetUrl,
  });

  final String campaignId;
  final String campaignVersionId;
  final String assignmentId;
  final String variantId;
  final String exposureId;
  final String placement;
  final int priority;
  final Map<String, WtsExperienceTranslation> translations;
  final bool closeable;
  final String themePreset;
  final double delaySeconds;
  final double? autoCloseSeconds;
  final Uri? assetUrl;
}

typedef WtsExperienceAvailableHandler = void Function(WtsExperience experience);
typedef WtsExperienceActionHandler = void Function(
  WtsExperience experience,
  WtsExperienceAction action,
);
typedef WtsUnsubscribe = void Function();

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
  static final Set<WtsExperienceAvailableHandler> _experienceAvailableHandlers =
      <WtsExperienceAvailableHandler>{};
  static final Set<WtsExperienceActionHandler> _experienceActionHandlers =
      <WtsExperienceActionHandler>{};
  static bool _experienceCallbacksConfigured = false;

  @visibleForTesting
  static set platform(WtsPlatform value) => _platform = value;

  static Future<void> configure({
    required String appKey,
    String? apiBaseUrl,
    String? collectorBaseUrl,
    WtsExperienceOptions experiences = const WtsExperienceOptions(),
  }) {
    if (_platform is PigeonWtsPlatform) _ensureExperienceCallbacks();
    return _guard(() =>
        _platform.configure(appKey, apiBaseUrl, collectorBaseUrl, experiences));
  }

  static Future<WtsDeepLink> handle(Uri uri) =>
      _guard(() => _platform.handle(uri.toString()), fallbackUrl: uri);

  static Future<WtsDeepLink?> getDeferredDeepLink() =>
      _guard(_platform.getDeferredDeepLink);

  static Future<void> setProfileConsent(bool granted) =>
      _guard(() => _platform.setProfileConsent(granted));

  static Future<void> identify(
    String externalUserId, {
    Map<String, Object> attributes = const {},
  }) {
    _validateUserAttributes(attributes);
    return _guard(() => _platform.identify(externalUserId, attributes));
  }

  static Future<void> updateUser(WtsUserUpdate update) {
    _validateUserUpdate(update);
    return _guard(() => _platform.updateUser(update));
  }

  static Future<void> setReportedAttribution(
          WtsReportedAttribution attribution) =>
      _guard(() => _platform.setReportedAttribution(attribution));

  static Future<void> resetIdentity() => _guard(_platform.resetIdentity);

  static Future<void> track(
    String eventKey, {
    Map<String, Object> properties = const {},
    WtsRevenue? revenue,
    String? linkId,
  }) {
    _validateProperties(properties);
    return _guard(() => _platform.track(eventKey, properties, revenue, linkId));
  }

  static Future<void> screen(
    String name, {
    Map<String, Object> properties = const {},
  }) {
    _validateProperties(properties);
    if (name.trim().isEmpty || name.trim().length > 120) {
      throw ArgumentError.value(
          name, 'name', 'Expected a screen name of 1 to 120 characters.');
    }
    return _guard(() => _platform.screen(name.trim(), properties));
  }

  static Future<void> setExperienceConsent(WtsExperienceConsent consent) =>
      _guard(() => _platform.setExperienceConsent(consent));

  static Future<bool> presentNextExperience() =>
      _guard(_platform.presentNextExperience);

  static Future<bool> dismissCurrentExperience() =>
      _guard(_platform.dismissCurrentExperience);

  static Future<WtsExperienceDiagnostics> getExperienceDiagnostics() =>
      _guard(_platform.getExperienceDiagnostics);

  static WtsUnsubscribe onExperienceAvailable(
    WtsExperienceAvailableHandler handler,
  ) {
    if (_platform is PigeonWtsPlatform) _ensureExperienceCallbacks();
    _experienceAvailableHandlers.add(handler);
    return () => _experienceAvailableHandlers.remove(handler);
  }

  static WtsUnsubscribe onExperienceAction(
    WtsExperienceActionHandler handler,
  ) {
    if (_platform is PigeonWtsPlatform) _ensureExperienceCallbacks();
    _experienceActionHandlers.add(handler);
    return () => _experienceActionHandlers.remove(handler);
  }

  static Future<void> flush() => _guard(_platform.flush);

  static void _ensureExperienceCallbacks() {
    if (_experienceCallbacksConfigured) return;
    WtsFlutterApi.setUp(_WtsFlutterCallbacks());
    _experienceCallbacksConfigured = true;
  }

  static Future<T> _guard<T>(
    Future<T> Function() operation, {
    Uri? fallbackUrl,
  }) async {
    try {
      return await operation();
    } on PlatformException catch (error) {
      final Uri? nativeFallback = error.details is String
          ? Uri.tryParse(error.details as String)
          : null;
      throw WtsSdkException(
        error.code,
        error.message ?? 'Native SDK error.',
        fallbackUrl: fallbackUrl ?? nativeFallback,
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

  static void _validateUserAttributes(Map<String, Object> attributes) {
    if (attributes.length > 50) {
      throw ArgumentError.value(
          attributes, 'attributes', 'At most 50 attributes are supported.');
    }
    for (final MapEntry<String, Object> entry in attributes.entries) {
      if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(entry.key)) {
        throw ArgumentError.value(
            entry.key, 'attribute key', 'Expected lowercase snake_case.');
      }
      final Object value = entry.value;
      if (value is! String &&
          value is! num &&
          value is! bool &&
          value is! DateTime &&
          value is! List<String>) {
        throw ArgumentError.value(value, entry.key,
            'Expected String, number, bool, DateTime, or List<String>.');
      }
    }
  }

  static void _validateUserUpdate(WtsUserUpdate update) {
    _validateUserAttributes(update.set);
    _validateUserAttributes(update.setOnce);
    final List<String> keys = <String>[
      ...update.set.keys,
      ...update.setOnce.keys,
      ...update.unset,
      ...update.increment.keys,
    ];
    if (keys.isEmpty ||
        keys.length > 50 ||
        keys.toSet().length != keys.length) {
      throw ArgumentError.value(
        update,
        'update',
        'Expected 1 to 50 unique attribute operations.',
      );
    }
    for (final String key in <String>[
      ...update.unset,
      ...update.increment.keys
    ]) {
      if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(key)) {
        throw ArgumentError.value(
            key, 'attribute key', 'Expected lowercase snake_case.');
      }
    }
  }
}

class _WtsFlutterCallbacks implements WtsFlutterApi {
  @override
  void onExperienceAvailable(WtsExperienceData experience) {
    final WtsExperience value = _experienceFromData(experience);
    for (final WtsExperienceAvailableHandler handler
        in List<WtsExperienceAvailableHandler>.of(
            WtsSdk._experienceAvailableHandlers)) {
      handler(value);
    }
  }

  @override
  void onExperienceAction(
    WtsExperienceData experience,
    WtsExperienceActionData action,
  ) {
    final WtsExperience value = _experienceFromData(experience);
    final WtsExperienceAction actionValue = _actionFromData(action);
    for (final WtsExperienceActionHandler handler
        in List<WtsExperienceActionHandler>.of(
            WtsSdk._experienceActionHandlers)) {
      handler(value, actionValue);
    }
  }
}

WtsExperience _experienceFromData(WtsExperienceData data) => WtsExperience(
      campaignId: data.campaignId,
      campaignVersionId: data.campaignVersionId,
      assignmentId: data.assignmentId,
      variantId: data.variantId,
      exposureId: data.exposureId,
      placement: data.placement,
      priority: data.priority,
      translations: <String, WtsExperienceTranslation>{
        for (final WtsExperienceTranslationData item in data.translations)
          item.locale: WtsExperienceTranslation(
            title: item.title,
            description: item.description,
            primaryAction: item.primaryAction == null
                ? null
                : _actionFromData(item.primaryAction!),
            secondaryAction: item.secondaryAction == null
                ? null
                : _actionFromData(item.secondaryAction!),
          ),
      },
      closeable: data.closeable,
      themePreset: data.themePreset,
      delaySeconds: data.delaySeconds,
      autoCloseSeconds: data.autoCloseSeconds,
      assetUrl: data.assetUrl == null ? null : Uri.tryParse(data.assetUrl!),
    );

WtsExperienceAction _actionFromData(WtsExperienceActionData data) =>
    WtsExperienceAction(
      id: data.id,
      label: data.label,
      type: data.type,
      target: data.target,
    );

abstract interface class WtsPlatform {
  Future<void> configure(
    String appKey,
    String? apiBaseUrl,
    String? collectorBaseUrl,
    WtsExperienceOptions experiences,
  );
  Future<WtsDeepLink> handle(String url);
  Future<WtsDeepLink?> getDeferredDeepLink();
  Future<void> setProfileConsent(bool granted);
  Future<void> identify(String externalUserId, Map<String, Object> attributes);
  Future<void> updateUser(WtsUserUpdate update);
  Future<void> setReportedAttribution(WtsReportedAttribution attribution);
  Future<void> resetIdentity();
  Future<void> track(
    String eventKey,
    Map<String, Object> properties,
    WtsRevenue? revenue,
    String? linkId,
  );
  Future<void> screen(String name, Map<String, Object> properties);
  Future<void> setExperienceConsent(WtsExperienceConsent consent);
  Future<bool> presentNextExperience();
  Future<bool> dismissCurrentExperience();
  Future<WtsExperienceDiagnostics> getExperienceDiagnostics();
  Future<void> flush();
}

class PigeonWtsPlatform implements WtsPlatform {
  final WtsHostApi _api = WtsHostApi();

  @override
  Future<void> configure(
    String appKey,
    String? apiBaseUrl,
    String? collectorBaseUrl,
    WtsExperienceOptions experiences,
  ) =>
      _api.configure(WtsConfigurationData(
        appKey: appKey,
        apiBaseUrl: apiBaseUrl,
        collectorBaseUrl: collectorBaseUrl,
        experiencesEnabled: experiences.enabled,
        experienceRenderMode: experiences.renderMode.name,
        allowedInternalRoutes: experiences.allowedInternalRoutes.toList(),
        allowedCallbackKeys: experiences.allowedCallbackKeys.toList(),
        allowedDeepLinkHosts: experiences.allowedDeepLinkHosts.toList(),
        allowedDeepLinkSchemes: experiences.allowedDeepLinkSchemes.toList(),
        allowedWebOrigins: experiences.allowedWebOrigins.toList(),
      ));

  @override
  Future<WtsDeepLink> handle(String url) async =>
      _fromData(await _api.handle(url));

  @override
  Future<WtsDeepLink?> getDeferredDeepLink() async {
    final WtsDeepLinkData? result = await _api.getDeferredDeepLink();
    return result == null ? null : _fromData(result);
  }

  @override
  Future<void> setProfileConsent(bool granted) =>
      _api.setProfileConsent(granted);

  @override
  Future<void> identify(
          String externalUserId, Map<String, Object> attributes) =>
      _api.identify(
        externalUserId,
        attributes.entries.map(_userParameter).toList(growable: false),
      );

  @override
  Future<void> updateUser(WtsUserUpdate update) => _api.updateUser(
        WtsUserUpdateData(
          set: update.set.entries.map(_userParameter).toList(growable: false),
          setOnce: update.setOnce.entries
              .map(_userParameter)
              .toList(growable: false),
          unset: update.unset,
          increment: update.increment.entries
              .map((MapEntry<String, num> entry) => WtsIncrementData(
                    key: entry.key,
                    value: entry.value.toDouble(),
                  ))
              .toList(growable: false),
        ),
      );

  @override
  Future<void> setReportedAttribution(WtsReportedAttribution attribution) =>
      _api.setReportedAttribution(
        WtsReportedAttributionData(
          source: attribution.source,
          medium: attribution.medium,
          campaign: attribution.campaign,
          externalRef: attribution.externalRef,
        ),
      );

  @override
  Future<void> resetIdentity() => _api.resetIdentity();

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
  Future<void> screen(String name, Map<String, Object> properties) =>
      _api.screen(
        name,
        properties.entries.map(_parameter).toList(growable: false),
      );

  @override
  Future<void> setExperienceConsent(WtsExperienceConsent consent) async {
    await _api.setExperienceConsent(consent.name);
  }

  @override
  Future<bool> presentNextExperience() => _api.presentNextExperience();

  @override
  Future<bool> dismissCurrentExperience() => _api.dismissCurrentExperience();

  @override
  Future<WtsExperienceDiagnostics> getExperienceDiagnostics() async {
    final WtsExperienceDiagnosticsData data =
        await _api.getExperienceDiagnostics();
    return WtsExperienceDiagnostics(
      enabled: data.enabled,
      consent: WtsExperienceConsent.values.byName(data.consent),
      queued: data.queued,
      presenting: data.presenting,
      testDeviceToken: data.testDeviceToken,
      lastErrorCode: data.lastErrorCode,
    );
  }

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

  static WtsParameterData _userParameter(MapEntry<String, Object> entry) {
    final Object value = entry.value;
    if (value is DateTime) {
      return WtsParameterData(
        key: entry.key,
        kind: WtsValueKind.date,
        stringValue: value.toUtc().toIso8601String(),
      );
    }
    if (value is List<String>) {
      return WtsParameterData(
        key: entry.key,
        kind: WtsValueKind.stringArray,
        stringArrayValue: value,
      );
    }
    return _parameter(entry);
  }

  static Object _value(WtsParameterData item) => switch (item.kind) {
        WtsValueKind.string => item.stringValue!,
        WtsValueKind.number => item.numberValue!,
        WtsValueKind.boolean => item.booleanValue!,
        WtsValueKind.date => item.stringValue!,
        WtsValueKind.stringArray => item.stringArrayValue!,
      };
}
