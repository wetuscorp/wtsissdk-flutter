import Flutter
import UIKit
import WtsSDK

public final class WtsSdkPlugin: NSObject, FlutterPlugin, WtsHostApi {
    public static func register(with registrar: FlutterPluginRegistrar) {
        WtsHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: WtsSdkPlugin())
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
                try await WtsSDK.shared.configure(appKey: configuration.appKey, options: options)
                completion(.success(()))
            } catch { completion(.failure(error)) }
        }
    }

    func handle(url: String, completion: @escaping (Result<WtsDeepLinkData, Error>) -> Void) {
        Task {
            do {
                guard let url = URL(string: url) else { throw WtsSDKError.invalidURL(fallbackURL: nil) }
                completion(.success(try await WtsSDK.shared.handle(url: url).toData()))
            } catch { completion(.failure(error)) }
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
            } catch { completion(.failure(error)) }
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
            } catch { completion(.failure(error)) }
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
            } catch { completion(.failure(error)) }
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
            } catch { completion(.failure(error)) }
        }
    }

    func resetIdentity(completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await WtsSDK.shared.resetIdentity()
                completion(.success(()))
            } catch { completion(.failure(error)) }
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
            } catch { completion(.failure(error)) }
        }
    }

    func flush(completion: @escaping (Result<Void, Error>) -> Void) {
        Task { await WtsSDK.shared.flush(); completion(.success(())) }
    }
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
