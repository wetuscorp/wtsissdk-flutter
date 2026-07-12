package co.wetus.sdk.flutter

import android.content.Context
import android.net.Uri
import co.wetus.sdk.WtsDeepLink
import co.wetus.sdk.WtsOptions
import co.wetus.sdk.WtsRevenue
import co.wetus.sdk.WtsSdk
import co.wetus.sdk.WtsValue
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class WtsSdkPlugin : FlutterPlugin, WtsHostApi {
    private lateinit var context: Context
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        WtsHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        WtsHostApi.setUp(binding.binaryMessenger, null)
        scope.cancel()
    }

    override fun configure(configuration: WtsConfigurationData, callback: (Result<Unit>) -> Unit) {
        callback(runCatching {
            WtsSdk.configure(
                context,
                configuration.appKey,
                WtsOptions(apiBaseUrl = configuration.apiBaseUrl ?: "https://api.wts.is/api/v1"),
            )
        }.map { Unit })
    }

    override fun handle(url: String, callback: (Result<WtsDeepLinkData>) -> Unit) = launch(callback) {
        WtsSdk.shared().handle(Uri.parse(url)).toData()
    }

    override fun getDeferredDeepLink(callback: (Result<WtsDeepLinkData?>) -> Unit) = launch(callback) {
        WtsSdk.shared().getDeferredDeepLink()?.toData()
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

    override fun flush(callback: (Result<Unit>) -> Unit) = launch(callback) { WtsSdk.shared().flush() }

    private fun <T> launch(callback: (Result<T>) -> Unit, block: suspend () -> T) {
        scope.launch { callback(runCatching { block() }) }
    }

    private fun WtsDeepLink.toData() = WtsDeepLinkData(
        path = path,
        parameters = parameters.map { (key, value) -> value.toData(key) },
        linkId = linkId,
        attributionId = attributionId,
        isDeferred = isDeferred,
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
    }
}
