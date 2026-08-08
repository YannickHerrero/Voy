import CloudKit
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppState {
    enum CloudStatus: Equatable {
        case checking
        case available
        case unavailable(String)
    }

    let modelContainer: ModelContainer
    private(set) var cloudStatus: CloudStatus = .checking
    private(set) var persistenceNotice: String?
    private var didBootstrap = false
    private let skipsCloudChecks: Bool

    init() {
        let environment = ProcessInfo.processInfo.environment
        var shouldSkipCloud = environment["XCTestConfigurationFilePath"] != nil
            || environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
#if DEBUG
        shouldSkipCloud = shouldSkipCloud || ProcessInfo.processInfo.arguments.contains("-UseLocalStore")
#endif
        skipsCloudChecks = shouldSkipCloud

        if skipsCloudChecks {
            do {
                modelContainer = try DataSchema.inMemoryContainer()
                cloudStatus = .available
                return
            } catch {
                fatalError("Unable to create the test data store: \(error.localizedDescription)")
            }
        }

        do {
            let configuration = ModelConfiguration(
                "Voy",
                schema: DataSchema.schema,
                cloudKitDatabase: .automatic
            )
            modelContainer = try ModelContainer(
                for: DataSchema.schema,
                configurations: [configuration]
            )
        } catch {
            do {
                let fallback = ModelConfiguration(
                    "VoyOffline",
                    schema: DataSchema.schema,
                    cloudKitDatabase: .none
                )
                modelContainer = try ModelContainer(
                    for: DataSchema.schema,
                    configurations: [fallback]
                )
                persistenceNotice = "iCloud sync is temporarily unavailable. Changes are being saved on this device."
            } catch {
                fatalError("Unable to create the local data store: \(error.localizedDescription)")
            }
        }
    }

    func bootstrapIfNeeded(using context: ModelContext) {
        guard !didBootstrap else { return }
        didBootstrap = true

        do {
            try DataSeeder.seedIfNeeded(in: context)
#if DEBUG
            try DebugSampleData.seedIfRequested(in: context)
#endif
        } catch {
            persistenceNotice = "Voy could not finish preparing your library. You can continue and try again later."
        }
    }

    func refreshCloudStatus() async {
        guard !skipsCloudChecks else { return }
        do {
            let status = try await CKContainer(identifier: "iCloud.com.yannickherrero.voy").accountStatus()
            switch status {
            case .available:
                cloudStatus = .available
            case .noAccount:
                cloudStatus = .unavailable("Sign in to iCloud to sync between devices. Voy remains available offline.")
            case .restricted:
                cloudStatus = .unavailable("iCloud access is restricted. Voy remains available offline.")
            case .couldNotDetermine, .temporarilyUnavailable:
                cloudStatus = .unavailable("iCloud sync is temporarily unavailable. Your changes remain saved offline.")
            @unknown default:
                cloudStatus = .unavailable("iCloud status could not be determined. Your changes remain saved offline.")
            }
        } catch {
            cloudStatus = .unavailable("iCloud status could not be checked. Your changes remain saved offline.")
        }
    }
}
