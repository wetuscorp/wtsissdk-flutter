import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/src/main/kotlin/co/wetus/sdk/flutter/WtsMessages.g.kt',
    kotlinOptions: KotlinOptions(package: 'co.wetus.sdk.flutter'),
    swiftOut: 'ios/wts_sdk/Sources/wts_sdk/WtsMessages.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'wts_sdk',
  ),
)
enum WtsValueKind { string, number, boolean, date, stringArray }

class WtsParameterData {
  WtsParameterData({
    required this.key,
    required this.kind,
    this.stringValue,
    this.numberValue,
    this.booleanValue,
    this.stringArrayValue,
  });
  String key;
  WtsValueKind kind;
  String? stringValue;
  double? numberValue;
  bool? booleanValue;
  List<String>? stringArrayValue;
}

class WtsUserUpdateData {
  WtsUserUpdateData({
    required this.set,
    required this.setOnce,
    required this.unset,
    required this.increment,
  });
  List<WtsParameterData> set;
  List<WtsParameterData> setOnce;
  List<String> unset;
  List<WtsIncrementData> increment;
}

class WtsIncrementData {
  WtsIncrementData({required this.key, required this.value});
  String key;
  double value;
}

class WtsReportedAttributionData {
  WtsReportedAttributionData({
    required this.source,
    this.medium,
    this.campaign,
    this.externalRef,
  });
  String source;
  String? medium;
  String? campaign;
  String? externalRef;
}

class WtsDeepLinkData {
  WtsDeepLinkData({
    required this.path,
    required this.parameters,
    required this.linkId,
    required this.attributionId,
    required this.isDeferred,
  });
  String path;
  List<WtsParameterData> parameters;
  String linkId;
  String attributionId;
  bool isDeferred;
}

class WtsRevenueData {
  WtsRevenueData({required this.amount, required this.currency});
  String amount;
  String currency;
}

class WtsConfigurationData {
  WtsConfigurationData({
    required this.appKey,
    this.apiBaseUrl,
    this.collectorBaseUrl,
    required this.experiencesEnabled,
    required this.experienceRenderMode,
    required this.allowedInternalRoutes,
    required this.allowedCallbackKeys,
    required this.allowedDeepLinkHosts,
    required this.allowedDeepLinkSchemes,
    required this.allowedWebOrigins,
  });
  String appKey;
  String? apiBaseUrl;
  String? collectorBaseUrl;
  bool experiencesEnabled;
  String experienceRenderMode;
  List<String> allowedInternalRoutes;
  List<String> allowedCallbackKeys;
  List<String> allowedDeepLinkHosts;
  List<String> allowedDeepLinkSchemes;
  List<String> allowedWebOrigins;
}

class WtsExperienceDiagnosticsData {
  WtsExperienceDiagnosticsData({
    required this.enabled,
    required this.consent,
    required this.queued,
    required this.presenting,
    required this.testDeviceToken,
    this.lastErrorCode,
  });
  bool enabled;
  String consent;
  int queued;
  bool presenting;
  String testDeviceToken;
  String? lastErrorCode;
}

class WtsExperienceActionData {
  WtsExperienceActionData({
    required this.id,
    required this.label,
    required this.type,
    this.target,
  });
  String id;
  String label;
  String type;
  String? target;
}

class WtsExperienceTranslationData {
  WtsExperienceTranslationData({
    required this.locale,
    required this.title,
    required this.description,
    this.primaryAction,
    this.secondaryAction,
  });
  String locale;
  String title;
  String description;
  WtsExperienceActionData? primaryAction;
  WtsExperienceActionData? secondaryAction;
}

class WtsExperienceData {
  WtsExperienceData({
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
  String campaignId;
  String campaignVersionId;
  String assignmentId;
  String variantId;
  String exposureId;
  String placement;
  int priority;
  List<WtsExperienceTranslationData> translations;
  bool closeable;
  String themePreset;
  double delaySeconds;
  double? autoCloseSeconds;
  String? assetUrl;
}

@FlutterApi()
abstract class WtsFlutterApi {
  void onExperienceAvailable(WtsExperienceData experience);

  void onExperienceAction(
    WtsExperienceData experience,
    WtsExperienceActionData action,
  );
}

@HostApi()
abstract class WtsHostApi {
  @async
  void configure(WtsConfigurationData configuration);

  @async
  WtsDeepLinkData handle(String url);

  @async
  WtsDeepLinkData? getDeferredDeepLink();

  @async
  void setProfileConsent(bool granted);

  @async
  void identify(String externalUserId, List<WtsParameterData> attributes);

  @async
  void updateUser(WtsUserUpdateData update);

  @async
  void setReportedAttribution(WtsReportedAttributionData attribution);

  @async
  void resetIdentity();

  @async
  void track(
    String eventKey,
    List<WtsParameterData> properties,
    WtsRevenueData? revenue,
    String? linkId,
  );

  @async
  void screen(String name, List<WtsParameterData> properties);

  @async
  String setExperienceConsent(String consent);

  @async
  bool presentNextExperience();

  @async
  bool dismissCurrentExperience();

  @async
  WtsExperienceDiagnosticsData getExperienceDiagnostics();

  @async
  void flush();
}
