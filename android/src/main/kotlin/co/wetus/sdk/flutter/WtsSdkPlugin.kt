package co.wetus.sdk.flutter

import android.content.Context
import android.net.Uri
import co.wetus.sdk.WtsConsentState
import co.wetus.sdk.WtsDeepLink
import co.wetus.sdk.WtsExperience
import co.wetus.sdk.WtsExperienceAction
import co.wetus.sdk.WtsOptions
import co.wetus.sdk.WtsRevenue
import co.wetus.sdk.WtsReportedAttribution
import co.wetus.sdk.WtsSdk
import co.wetus.sdk.WtsSdkException
import co.wetus.sdk.WtsSdkFamily
import co.wetus.sdk.WtsTestSessionExperienceDecision
import co.wetus.sdk.WtsTestSessionPairing
import co.wetus.sdk.WtsTestSessionProbeLink
import co.wetus.sdk.WtsTestSessionProbeResult
import co.wetus.sdk.WtsTestSessionProbeRunResult
import co.wetus.sdk.WtsUserUpdate
import co.wetus.sdk.WtsUserValue
import co.wetus.sdk.WtsValue
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlin.coroutines.resume

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
                ),
            )
            sdk.onExperienceAction { experience, action ->
                withContext(Dispatchers.Main.immediate) {
                    suspendCancellableCoroutine { continuation ->
                        val api = flutterApi
                        if (api == null) {
                            continuation.resume(false)
                            return@suspendCancellableCoroutine
                        }
                        api.onExperienceAction(
                        experience.toData(),
                        action.toData(),
                        ) { result ->
                            if (continuation.isActive) {
                                continuation.resume(result.getOrDefault(false))
                            }
                        }
                    }
                }
            }
        }.map { Unit }.forFlutter())
    }

    override fun handle(url: String, callback: (Result<WtsDeepLinkData>) -> Unit) = launch(callback) {
        WtsSdk.shared().handle(Uri.parse(url)).toData()
    }

    override fun getDeferredDeepLink(callback: (Result<WtsDeepLinkData?>) -> Unit) = launch(callback) {
        WtsSdk.shared().getDeferredDeepLink()?.toData()
    }

    override fun setConsent(consent: String, callback: (Result<Unit>) -> Unit) = launch(callback) {
        WtsSdk.shared().setConsent(WtsConsentState.valueOf(consent.uppercase()))
    }

    override fun getConsentState(callback: (Result<String>) -> Unit) {
        callback(runCatching { WtsSdk.shared().getConsentState().name.lowercase() }.forFlutter())
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

    override fun joinTestSession(
        pairing: String,
        callback: (Result<WtsTestSessionJoinData>) -> Unit,
    ) = launch(callback) {
        WtsSdk.shared().joinTestSession(
            WtsTestSessionPairing.from(pairing),
            WtsSdkFamily.FLUTTER,
        ).let { result ->
            WtsTestSessionJoinData(
                accepted = result.accepted,
                joined = result.joined,
                compatible = result.compatible,
                checks = result.checks.map {
                    WtsTestSessionCheckData(it.key, it.status, it.code, it.message)
                },
                requiredSdkVersion = result.requiredSdkVersion,
                sessionId = result.sessionId,
                expiresAt = result.expiresAt,
                testProfileExternalUserId = result.testProfileExternalUserId,
                errorCode = result.errorCode,
            )
        }
    }

    override fun leaveTestSession(callback: (Result<Boolean>) -> Unit) = launch(callback) {
        WtsSdk.shared().leaveTestSession()
    }

    override fun getTestSessionDiagnostics(
        callback: (Result<WtsTestSessionDiagnosticsData>) -> Unit,
    ) {
        callback(runCatching {
            WtsSdk.shared().getTestSessionDiagnostics().let { result ->
                WtsTestSessionDiagnosticsData(
                    joined = result.joined,
                    compatible = result.compatible,
                    checks = result.checks.map {
                        WtsTestSessionCheckData(it.key, it.status, it.code, it.message)
                    },
                    pendingSignals = result.pendingSignals.toLong(),
                    sessionId = result.sessionId,
                    expiresAt = result.expiresAt,
                    requiredSdkVersion = result.requiredSdkVersion,
                    lastErrorCode = result.lastErrorCode,
                )
            }
        }.forFlutter())
    }

    override fun probeTestSessionUrl(
        url: String,
        callback: (Result<WtsTestSessionProbeData>) -> Unit,
    ) = launch(callback) { WtsSdk.shared().probeTestSessionUrl(url).toData() }

    override fun runTestSessionProbes(
        callback: (Result<WtsTestSessionProbeRunData>) -> Unit,
    ) = launch(callback) { WtsSdk.shared().runTestSessionProbes().toData() }

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

    private fun WtsTestSessionProbeResult.toData() = WtsTestSessionProbeData(
        match = match,
        status = status,
        code = code,
        originalUrl = originalUrl,
        fallbackUrl = fallbackUrl,
        link = link?.toData(),
    )

    private fun WtsTestSessionProbeLink.toData() = WtsTestSessionProbeLinkData(
        id = id,
        path = path,
        parametersJson = Json.encodeToString(
            JsonObject.serializer(),
            JsonObject(parameters.mapValues { (_, value) -> value.toTestJson() }),
        ),
    )

    private fun WtsTestSessionProbeRunResult.toData() = WtsTestSessionProbeRunData(
        accepted = accepted,
        emitted = emitted,
        skipped = skipped,
        pendingSignals = pendingSignals.toLong(),
        experienceDecisionJson = experienceDecision?.toTestJson()?.toString(),
    )

    private fun WtsTestSessionExperienceDecision.toTestJson() = JsonObject(
        buildMap {
            put("outcome", JsonPrimitive(outcome))
            put("reason", reason?.let(::JsonPrimitive) ?: JsonNull)
            put("testGrant", testGrant?.let { grant ->
                JsonObject(
                    mapOf(
                        "fixtureId" to JsonPrimitive(grant.fixtureId),
                        "expiresAt" to JsonPrimitive(grant.expiresAt),
                    ),
                )
            } ?: JsonNull)
            put("decision", decision?.let { decision ->
                JsonObject(
                    buildMap {
                        put("campaignId", JsonPrimitive(decision.campaignId))
                        put("campaignVersionId", JsonPrimitive(decision.campaignVersionId))
                        put("placement", JsonPrimitive(decision.placement))
                        put("defaultLocale", JsonPrimitive(decision.defaultLocale))
                        put("variant", decision.variant?.let { variant ->
                            JsonObject(
                                buildMap {
                                    put("id", JsonPrimitive(variant.id))
                                    put("key", JsonPrimitive(variant.key))
                                    put("content", variant.content)
                                    put("asset", variant.assetUrl?.let { url ->
                                        JsonObject(mapOf("url" to JsonPrimitive(url)))
                                    } ?: JsonNull)
                                },
                            )
                        } ?: JsonNull)
                    },
                )
            } ?: JsonNull)
        },
    )

    private fun WtsValue.toTestJson() = when (this) {
        is WtsValue.StringValue -> JsonPrimitive(value)
        is WtsValue.NumberValue -> JsonPrimitive(value)
        is WtsValue.BooleanValue -> JsonPrimitive(value)
    }

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
