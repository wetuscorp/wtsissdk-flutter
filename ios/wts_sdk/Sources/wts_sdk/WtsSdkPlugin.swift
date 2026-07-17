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
                options.experiences = WtsExperienceOptions(
                    enabled: configuration.experiencesEnabled,
                    renderMode: configuration.experienceRenderMode == "manual"
                        ? .manual
                        : .automatic,
                    allowedInternalRoutes: Set(configuration.allowedInternalRoutes),
                    allowedCallbackKeys: Set(configuration.allowedCallbackKeys),
                    allowedDeepLinkHosts: Set(configuration.allowedDeepLinkHosts),
                    allowedDeepLinkSchemes: Set(configuration.allowedDeepLinkSchemes),
                    allowedWebOrigins: Set(configuration.allowedWebOrigins)
                )
                try await WtsSDK.shared.configure(appKey: configuration.appKey, options: options)
                await WtsSDK.shared.onExperienceAvailable { [weak self] experience in
                    guard let self else { return }
                    DispatchQueue.main.async {
                        self.flutterApi.onExperienceAvailable(
                            experience: experience.toData()
                        ) { _ in }
                    }
                }
                await WtsSDK.shared.onExperienceAction { [weak self] experience, action in
                    guard let self else { return false }
                    DispatchQueue.main.async {
                        self.flutterApi.onExperienceAction(
                            experience: experience.toData(),
                            action: action.toData()
                        ) { _ in }
                    }
                    return false
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

    func setProfileConsent(
        granted: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await WtsSDK.shared.setProfileConsent(granted ? .granted : .denied)
                completion(.success(()))
            } catch { completion(.failure(platformError(error))) }
        }
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

    func setExperienceConsent(
        consent: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        Task {
            do {
                guard let value = WtsExperienceConsent(rawValue: consent) else {
                    throw PigeonError(
                        code: "INVALID_EXPERIENCE_CONSENT",
                        message: "Unsupported experience consent value.",
                        details: nil
                    )
                }
                let result = try await WtsSDK.shared.setExperienceConsent(value)
                completion(.success(String(describing: result)))
            } catch { completion(.failure(platformError(error))) }
        }
    }

    func presentNextExperience(
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        Task {
            completion(.success(await WtsSDK.shared.presentNextExperience() != nil))
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
            exposureId: exposureId,
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
