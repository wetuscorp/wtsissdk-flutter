import Flutter
import UIKit
import WtsSDK

public final class WtsSdkPlugin: NSObject, FlutterPlugin, WtsHostApi {
    private let flutterApi: WtsFlutterApi

    private init(messenger: FlutterBinaryMessenger) {
        flutterApi = WtsFlutterApi(binaryMessenger: messenger)
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        WtsHostApiSetup.setUp(
            binaryMessenger: registrar.messenger(),
            api: WtsSdkPlugin(messenger: registrar.messenger())
        )
    }

    func configure(
        configuration: WtsConfigurationData,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                var options = WtsOptions()
                if let value = configuration.apiBaseUrl, let url = URL(string: value) {
                    options.apiBaseURL = url
                }
                if let value = configuration.collectorBaseUrl, let url = URL(string: value) {
                    options.collectorBaseURL = url
                }
                try await WtsSDK.shared.configure(appKey: configuration.appKey, options: options)
                await WtsSDK.shared.onExperienceAction { [weak self] experience, action in
                    guard let self else { return false }
                    return await withCheckedContinuation { continuation in
                        self.flutterApi.onExperienceAction(
                            experience: experience.toData(),
                            action: action.toData()
                        ) { result in
                            continuation.resume(returning: (try? result.get()) ?? false)
                        }
                    }
                }
                completion(.success(()))
            } catch { completion(.failure(platformError(error))) }
        }
    }

    func handle(url: String, completion: @escaping (Result<WtsDeepLinkData, Error>) -> Void) {
        Task {
            do {
                guard let url = URL(string: url) else { throw WtsSDKError.invalidURL(fallbackURL: nil) }
                completion(.success(try await WtsSDK.shared.handle(url: url).toData()))
            } catch { completion(.failure(platformError(error))) }
        }
    }

    func getDeferredDeepLink(completion: @escaping (Result<WtsDeepLinkData?, Error>) -> Void) {
        Task { completion(.success(await WtsSDK.shared.getDeferredDeepLink()?.toData())) }
    }

    func setConsent(
        consent: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                guard let value = WtsConsentState(rawValue: consent) else {
                    throw PigeonError(
                        code: "INVALID_CONSENT",
                        message: "Unsupported consent value.",
                        details: nil
                    )
                }
                try await WtsSDK.shared.setConsent(value)
                completion(.success(()))
            } catch { completion(.failure(platformError(error))) }
        }
    }

    func getConsentState(completion: @escaping (Result<String, Error>) -> Void) {
        Task { completion(.success(await WtsSDK.shared.getConsentState().rawValue)) }
    }

    func identify(
        externalUserId: String,
        attributes: [WtsParameterData],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await WtsSDK.shared.identify(
                    externalUserId,
                    attributes: Dictionary(
                        uniqueKeysWithValues: attributes.map { ($0.key, $0.toUserValue()) }
                    )
                )
                completion(.success(()))
            } catch { completion(.failure(platformError(error))) }
        }
    }

    func updateUser(
        update: WtsUserUpdateData,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await WtsSDK.shared.updateUser(
                    WtsUserUpdate(
                        set: Dictionary(
                            uniqueKeysWithValues: update.set.map { ($0.key, $0.toUserValue()) }
                        ),
                        setOnce: Dictionary(
                            uniqueKeysWithValues: update.setOnce.map {
                                ($0.key, $0.toUserValue())
                            }
                        ),
                        unset: update.unset,
                        increment: Dictionary(
                            uniqueKeysWithValues: update.increment.map { ($0.key, $0.value) }
                        )
                    )
                )
                completion(.success(()))
            } catch { completion(.failure(platformError(error))) }
        }
    }

    func setReportedAttribution(
        attribution: WtsReportedAttributionData,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await WtsSDK.shared.setReportedAttribution(
                    WtsReportedAttribution(
                        source: attribution.source,
                        medium: attribution.medium,
                        campaign: attribution.campaign,
                        externalRef: attribution.externalRef
                    )
                )
                completion(.success(()))
            } catch { completion(.failure(platformError(error))) }
        }
    }

    func resetIdentity(completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await WtsSDK.shared.resetIdentity()
                completion(.success(()))
            } catch { completion(.failure(platformError(error))) }
        }
    }

    func track(
        eventKey: String,
        properties: [WtsParameterData],
        revenue: WtsRevenueData?,
        linkId: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await WtsSDK.shared.track(
                    eventKey: eventKey,
                    properties: Dictionary(uniqueKeysWithValues: properties.map { ($0.key, $0.toValue()) }),
                    revenue: revenue.map { WtsRevenue(amount: $0.amount, currency: $0.currency) },
                    linkId: linkId
                )
                completion(.success(()))
            } catch { completion(.failure(platformError(error))) }
        }
    }

    func screen(
        name: String,
        properties: [WtsParameterData],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await WtsSDK.shared.screen(
                    name,
                    properties: Dictionary(
                        uniqueKeysWithValues: properties.map { ($0.key, $0.toValue()) }
                    )
                )
                completion(.success(()))
            } catch { completion(.failure(platformError(error))) }
        }
    }

    func dismissCurrentExperience(
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        Task {
            await WtsSDK.shared.dismissCurrentExperience()
            completion(.success(true))
        }
    }

    func getExperienceDiagnostics(
        completion: @escaping (Result<WtsExperienceDiagnosticsData, Error>) -> Void
    ) {
        Task {
            let value = await WtsSDK.shared.getExperienceDiagnostics()
            completion(
                .success(
                    WtsExperienceDiagnosticsData(
                        enabled: value.enabled,
                        consent: value.consent.rawValue,
                        queued: Int64(value.queued),
                        presenting: value.presenting,
                        testDeviceToken: value.testDeviceToken,
                        lastErrorCode: value.lastErrorCode
                    )
                )
            )
        }
    }

    func joinTestSession(
        pairing: String,
        completion: @escaping (Result<WtsTestSessionJoinData, Error>) -> Void
    ) {
        Task {
            do {
                let result = await WtsSDK.shared.joinTestSession(
                    try WtsTestSessionPairing.parse(pairing),
                    sdkFamily: .flutter
                )
                completion(.success(result.toData()))
            } catch { completion(.failure(platformError(error))) }
        }
    }

    func leaveTestSession(completion: @escaping (Result<Bool, Error>) -> Void) {
        Task { completion(.success(await WtsSDK.shared.leaveTestSession())) }
    }

    func getTestSessionDiagnostics(
        completion: @escaping (Result<WtsTestSessionDiagnosticsData, Error>) -> Void
    ) {
        Task { completion(.success(await WtsSDK.shared.getTestSessionDiagnostics().toData())) }
    }

    func probeTestSessionUrl(
        url: String,
        completion: @escaping (Result<WtsTestSessionProbeData, Error>) -> Void
    ) {
        Task {
            do {
                guard let value = URL(string: url) else { throw WtsSDKError.invalidURL(fallbackURL: nil) }
                completion(.success(try await WtsSDK.shared.probeTestSessionURL(value).toData()))
            } catch { completion(.failure(platformError(error))) }
        }
    }

    func runTestSessionProbes(
        completion: @escaping (Result<WtsTestSessionProbeRunData, Error>) -> Void
    ) {
        Task {
            do { completion(.success(try await WtsSDK.shared.runTestSessionProbes().toData())) }
            catch { completion(.failure(platformError(error))) }
        }
    }

    func flush(completion: @escaping (Result<Void, Error>) -> Void) {
        Task { await WtsSDK.shared.flush(); completion(.success(())) }
    }
}

private func platformError(_ error: Error) -> Error {
    guard let error = error as? WtsSDKError else {
        return PigeonError(
            code: "NATIVE_ERROR",
            message: error.localizedDescription,
            details: nil
        )
    }
    return PigeonError(
        code: error.code,
        message: error.localizedDescription,
        details: error.fallbackURL?.absoluteString
    )
}

private extension WtsDeepLink {
    func toData() -> WtsDeepLinkData {
        WtsDeepLinkData(
            path: path,
            parameters: parameters.map { $0.value.toData(key: $0.key) },
            linkId: linkId,
            attributionId: attributionId,
            isDeferred: isDeferred
        )
    }
}

private extension WtsExperience {
    func toData() -> WtsExperienceData {
        WtsExperienceData(
            campaignId: campaignId,
            campaignVersionId: campaignVersionId,
            assignmentId: assignmentId,
            variantId: variantId,
            placement: placement.rawValue,
            priority: Int64(priority),
            translations: content.translations.map { locale, value in
                WtsExperienceTranslationData(
                    locale: locale,
                    title: value.title,
                    description: value.description,
                    primaryAction: value.primaryAction?.toData(),
                    secondaryAction: value.secondaryAction?.toData()
                )
            },
            closeable: content.closeable,
            themePreset: content.themePreset,
            delaySeconds: content.delaySeconds,
            autoCloseSeconds: content.autoCloseSeconds,
            assetUrl: assetURL?.absoluteString
        )
    }
}

private extension WtsExperienceAction {
    func toData() -> WtsExperienceActionData {
        WtsExperienceActionData(
            id: id,
            label: label,
            type: type.rawValue,
            target: target
        )
    }
}

private extension WtsTestSessionCheck {
    func toData() -> WtsTestSessionCheckData {
        WtsTestSessionCheckData(key: key, status: status, code: code, message: message)
    }
}

private extension WtsTestSessionJoinResult {
    func toData() -> WtsTestSessionJoinData {
        WtsTestSessionJoinData(
            accepted: accepted,
            joined: joined,
            compatible: compatible,
            checks: checks.map { $0.toData() },
            requiredSdkVersion: requiredSDKVersion,
            sessionId: sessionId,
            expiresAt: expiresAt?.ISO8601Format(),
            testProfileExternalUserId: testProfileExternalUserId,
            errorCode: errorCode
        )
    }
}

private extension WtsTestSessionDiagnostics {
    func toData() -> WtsTestSessionDiagnosticsData {
        WtsTestSessionDiagnosticsData(
            joined: joined,
            compatible: compatible,
            checks: checks.map { $0.toData() },
            pendingSignals: Int64(pendingSignals),
            sessionId: sessionId,
            expiresAt: expiresAt?.ISO8601Format(),
            requiredSdkVersion: requiredSDKVersion,
            lastErrorCode: lastErrorCode
        )
    }
}

private extension WtsTestSessionProbeLink {
    func toData() -> WtsTestSessionProbeLinkData {
        WtsTestSessionProbeLinkData(
            id: id,
            path: path,
            parametersJson: testSessionJSONString(parameters.mapValues(\.foundationValue))
        )
    }
}

private extension WtsTestSessionProbeResult {
    func toData() -> WtsTestSessionProbeData {
        WtsTestSessionProbeData(
            match: match,
            status: status,
            code: code,
            originalUrl: originalURL.absoluteString,
            fallbackUrl: fallbackURL.absoluteString,
            link: link?.toData()
        )
    }
}

private extension WtsTestSessionProbeRunResult {
    func toData() -> WtsTestSessionProbeRunData {
        WtsTestSessionProbeRunData(
            accepted: accepted,
            emitted: emitted,
            skipped: skipped,
            pendingSignals: Int64(pendingSignals),
            experienceDecisionJson: experienceDecision.map { testSessionJSONString($0.jsonObject) }
        )
    }
}

private extension WtsTestSessionExperienceDecision {
    var jsonObject: [String: Any] {
        [
            "outcome": outcome,
            "reason": reason ?? NSNull(),
            "testGrant": testGrant.map {
                ["fixtureId": $0.fixtureId, "expiresAt": $0.expiresAt]
            } ?? NSNull(),
            "decision": decision.map { campaign in
                [
                    "campaignId": campaign.campaignId,
                    "campaignVersionId": campaign.campaignVersionId,
                    "placement": campaign.placement,
                    "defaultLocale": campaign.defaultLocale,
                    "variant": campaign.variant.map { variant in
                        [
                            "id": variant.id,
                            "key": variant.key,
                            "content": variant.content.foundationValue,
                            "asset": variant.assetURL.map { ["url": $0.absoluteString] } ?? NSNull(),
                        ]
                    } ?? NSNull(),
                ]
            } ?? NSNull(),
        ]
    }
}

private extension WtsTestSessionJSONValue {
    var foundationValue: Any {
        switch self {
        case .object(let value): value.mapValues(\.foundationValue)
        case .array(let value): value.map(\.foundationValue)
        case .string(let value): value
        case .number(let value): value
        case .bool(let value): value
        case .null: NSNull()
        }
    }
}

private func testSessionJSONString(_ value: Any) -> String {
    guard JSONSerialization.isValidJSONObject(value),
          let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
          let text = String(data: data, encoding: .utf8)
    else { return "{}" }
    return text
}

private extension WtsValue {
    func toData(key: String) -> WtsParameterData {
        switch self {
        case .string(let value): WtsParameterData(key: key, kind: .string, stringValue: value)
        case .number(let value): WtsParameterData(key: key, kind: .number, numberValue: value)
        case .boolean(let value): WtsParameterData(key: key, kind: .boolean, booleanValue: value)
        }
    }
}

private extension WtsParameterData {
    func toValue() -> WtsValue {
        switch kind {
        case .string: .string(stringValue ?? "")
        case .number: .number(numberValue ?? 0)
        case .boolean: .boolean(booleanValue ?? false)
        case .date: .string(stringValue ?? "")
        case .stringArray: .string(stringArrayValue?.first ?? "")
        }
    }

    func toUserValue() -> WtsUserValue {
        switch kind {
        case .string: .string(stringValue ?? "")
        case .number: .number(numberValue ?? 0)
        case .boolean: .boolean(booleanValue ?? false)
        case .date: .date(stringValue ?? "")
        case .stringArray: .stringArray(stringArrayValue ?? [])
        }
    }
}
