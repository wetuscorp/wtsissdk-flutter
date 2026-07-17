package co.wetus.sdk.flutter

import android.content.Context
import android.net.Uri
import co.wetus.sdk.WtsDeepLink
import co.wetus.sdk.WtsExperienceConsent
import co.wetus.sdk.WtsExperience
import co.wetus.sdk.WtsExperienceAction
import co.wetus.sdk.WtsExperienceOptions
import co.wetus.sdk.WtsExperienceRenderMode
import co.wetus.sdk.WtsOptions
import co.wetus.sdk.WtsRevenue
import co.wetus.sdk.WtsReportedAttribution
import co.wetus.sdk.WtsProfileConsent
import co.wetus.sdk.WtsSdk
import co.wetus.sdk.WtsSdkException
import co.wetus.sdk.WtsUserUpdate
import co.wetus.sdk.WtsUserValue
import co.wetus.sdk.WtsValue
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class WtsSdkPlugin : FlutterPlugin, WtsHostApi {
    private lateinit var context: Context
    private var flutterApi: WtsFlutterApi? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        flutterApi = WtsFlutterApi(binding.binaryMessenger)
        WtsHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        WtsHostApi.setUp(binding.binaryMessenger, null)
        runCatching {
            WtsSdk.shared().onExperienceAvailable(null)
            WtsSdk.shared().onExperienceAction(null)
        }
        flutterApi = null
        scope.cancel()
    }

    override fun configure(configuration: WtsConfigurationData, callback: (Result<Unit>) -> Unit) {
        callback(runCatching {
            val sdk = WtsSdk.configure(
                context,
                configuration.appKey,
                WtsOptions(
                    apiBaseUrl = configuration.apiBaseUrl ?: "https://api.wts.is/api/v1",
                    collectorBaseUrl = configuration.collectorBaseUrl
                        ?: "https://collect.wts.is",
                    experiences = WtsExperienceOptions(
                        enabled = configuration.experiencesEnabled,
                        renderMode = if (configuration.experienceRenderMode == "manual") {
                            WtsExperienceRenderMode.MANUAL
                        } else {
                            WtsExperienceRenderMode.AUTOMATIC
                        },
                        allowedInternalRoutes = configuration.allowedInternalRoutes.toSet(),
                        allowedCallbackKeys = configuration.allowedCallbackKeys.toSet(),
                        allowedDeepLinkHosts = configuration.allowedDeepLinkHosts.toSet(),
                        allowedDeepLinkSchemes = configuration.allowedDeepLinkSchemes.toSet(),
                        allowedWebOrigins = configuration.allowedWebOrigins.toSet(),
                    ),
                ),
            )
            sdk.onExperienceAvailable { experience ->
                scope.launch {
                    flutterApi?.onExperienceAvailable(experience.toData()) {}
                }
            }
            sdk.onExperienceAction { experience, action ->
                scope.launch {
                    flutterApi?.onExperienceAction(
                        experience.toData(),
                        action.toData(),
                    ) {}
                }
                false
            }
        }.map { Unit }.forFlutter())
    }

    override fun handle(url: String, callback: (Result<WtsDeepLinkData>) -> Unit) = launch(callback) {
        WtsSdk.shared().handle(Uri.parse(url)).toData()
    }

    override fun getDeferredDeepLink(callback: (Result<WtsDeepLinkData?>) -> Unit) = launch(callback) {
        WtsSdk.shared().getDeferredDeepLink()?.toData()
    }

    override fun setProfileConsent(granted: Boolean, callback: (Result<Unit>) -> Unit) {
        callback(runCatching {
            WtsSdk.shared().setProfileConsent(
                if (granted) WtsProfileConsent.GRANTED else WtsProfileConsent.DENIED,
            )
        }.forFlutter())
    }

    override fun identify(
        externalUserId: String,
        attributes: List<WtsParameterData>,
        callback: (Result<Unit>) -> Unit,
    ) = launch(callback) {
        WtsSdk.shared().identify(
            externalUserId,
            attributes.associate { it.key to it.toUserValue() },
        )
    }

    override fun updateUser(
        update: WtsUserUpdateData,
        callback: (Result<Unit>) -> Unit,
    ) = launch(callback) {
        WtsSdk.shared().updateUser(
            WtsUserUpdate(
                set = update.set.associate { it.key to it.toUserValue() },
                setOnce = update.setOnce.associate { it.key to it.toUserValue() },
                unset = update.unset,
                increment = update.increment.associate { it.key to it.value },
            ),
        )
    }

    override fun setReportedAttribution(
        attribution: WtsReportedAttributionData,
        callback: (Result<Unit>) -> Unit,
    ) = launch(callback) {
        WtsSdk.shared().setReportedAttribution(
            WtsReportedAttribution(
                source = attribution.source,
                medium = attribution.medium,
                campaign = attribution.campaign,
                externalRef = attribution.externalRef,
            ),
        )
    }

    override fun resetIdentity(callback: (Result<Unit>) -> Unit) = launch(callback) {
        WtsSdk.shared().resetIdentity()
    }

    override fun track(
        eventKey: String,
        properties: List<WtsParameterData>,
        revenue: WtsRevenueData?,
        linkId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = launch(callback) {
        WtsSdk.shared().track(
            eventKey,
            properties.associate { it.key to it.toValue() },
            revenue?.let { WtsRevenue(it.amount, it.currency) },
            linkId,
        )
    }

    override fun screen(
        name: String,
        properties: List<WtsParameterData>,
        callback: (Result<Unit>) -> Unit,
    ) = launch(callback) {
        WtsSdk.shared().screen(
            name,
            properties.associate { it.key to it.toValue() },
        )
    }

    override fun setExperienceConsent(
        consent: String,
        callback: (Result<String>) -> Unit,
    ) = launch(callback) {
        WtsSdk.shared().setExperienceConsent(
            WtsExperienceConsent.valueOf(consent.uppercase()),
        ).name.lowercase()
    }

    override fun presentNextExperience(callback: (Result<Boolean>) -> Unit) {
        callback(runCatching { WtsSdk.shared().presentNextExperience() }.forFlutter())
    }

    override fun dismissCurrentExperience(callback: (Result<Boolean>) -> Unit) {
        callback(runCatching { WtsSdk.shared().dismissCurrentExperience() }.forFlutter())
    }

    override fun getExperienceDiagnostics(
        callback: (Result<WtsExperienceDiagnosticsData>) -> Unit,
    ) {
        callback(
            runCatching {
                WtsSdk.shared().getExperienceDiagnostics().let {
                    WtsExperienceDiagnosticsData(
                        enabled = it.enabled,
                        consent = it.consent.name.lowercase(),
                        queued = it.queued.toLong(),
                        presenting = it.presenting,
                        testDeviceToken = it.testDeviceToken,
                        lastErrorCode = it.lastErrorCode,
                    )
                }
            }.forFlutter(),
        )
    }

    override fun flush(callback: (Result<Unit>) -> Unit) = launch(callback) { WtsSdk.shared().flush() }

    private fun <T> launch(callback: (Result<T>) -> Unit, block: suspend () -> T) {
        scope.launch { callback(runCatching { block() }.forFlutter()) }
    }

    private fun <T> Result<T>.forFlutter(): Result<T> = fold(
        onSuccess = { Result.success(it) },
        onFailure = { Result.failure(it.toFlutterError()) },
    )

    private fun Throwable.toFlutterError(): FlutterError {
        val sdkError = this as? WtsSdkException
        return FlutterError(
            code = sdkError?.code ?: "NATIVE_ERROR",
            message = message ?: "Native SDK error.",
            details = sdkError?.fallbackUri?.toString(),
        )
    }

    private fun WtsDeepLink.toData() = WtsDeepLinkData(
        path = path,
        parameters = parameters.map { (key, value) -> value.toData(key) },
        linkId = linkId,
        attributionId = attributionId,
        isDeferred = isDeferred,
    )

    private fun WtsExperience.toData() = WtsExperienceData(
        campaignId = campaignId,
        campaignVersionId = campaignVersionId,
        assignmentId = assignmentId,
        variantId = variantId,
        exposureId = exposureId,
        placement = placement.name.lowercase(),
        priority = priority.toLong(),
        translations = content.translations.map { (locale, value) ->
            WtsExperienceTranslationData(
                locale = locale,
                title = value.title,
                description = value.description,
                primaryAction = value.primaryAction?.toData(),
                secondaryAction = value.secondaryAction?.toData(),
            )
        },
        closeable = content.closeable,
        themePreset = content.themePreset,
        delaySeconds = content.delaySeconds,
        autoCloseSeconds = content.autoCloseSeconds,
        assetUrl = assetUrl,
    )

    private fun WtsExperienceAction.toData() = WtsExperienceActionData(
        id = id,
        label = label,
        type = type.name,
        target = target,
    )

    private fun WtsValue.toData(key: String) = when (this) {
        is WtsValue.StringValue -> WtsParameterData(key, WtsValueKind.STRING, stringValue = value)
        is WtsValue.NumberValue -> WtsParameterData(key, WtsValueKind.NUMBER, numberValue = value)
        is WtsValue.BooleanValue -> WtsParameterData(key, WtsValueKind.BOOLEAN, booleanValue = value)
    }

    private fun WtsParameterData.toValue() = when (kind) {
        WtsValueKind.STRING -> WtsValue.of(requireNotNull(stringValue))
        WtsValueKind.NUMBER -> WtsValue.of(requireNotNull(numberValue))
        WtsValueKind.BOOLEAN -> WtsValue.of(requireNotNull(booleanValue))
        WtsValueKind.DATE, WtsValueKind.STRING_ARRAY ->
            error("Event properties do not support profile-only value types.")
    }

    private fun WtsParameterData.toUserValue() = when (kind) {
        WtsValueKind.STRING -> WtsUserValue.of(requireNotNull(stringValue))
        WtsValueKind.NUMBER -> WtsUserValue.of(requireNotNull(numberValue))
        WtsValueKind.BOOLEAN -> WtsUserValue.of(requireNotNull(booleanValue))
        WtsValueKind.DATE -> WtsUserValue.date(requireNotNull(stringValue))
        WtsValueKind.STRING_ARRAY ->
            WtsUserValue.strings(requireNotNull(stringArrayValue))
    }
}
