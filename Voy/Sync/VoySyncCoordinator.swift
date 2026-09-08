import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class VoySyncCoordinator {
    enum State: Equatable {
        case disabled
        case idle
        case syncing(String)
        case synced(Date)
        case failed(String)
    }

    private(set) var state: State = .idle

    var isSyncing: Bool {
        if case .syncing = state { return true }
        return false
    }

    func markDisabled() {
        state = .disabled
    }

    func syncIfConfigured(using context: ModelContext, force: Bool = false) async {
        guard !isSyncing else { return }
        guard
            let baseURL = VoyServerConfiguration.serverURL,
            let scheme = baseURL.scheme?.lowercased(),
            scheme == "https" || (scheme == "http" && baseURL.host == "localhost"),
            let token = try? VoyServerCredentials.token(),
            token.count >= 32
        else {
            state = .disabled
            return
        }

        do {
            state = .syncing("Preparing mirror")
            let syncExport = try VoySyncEncoder.makeExport(
                from: context,
                deviceId: VoyServerConfiguration.deviceID
            )
            let fingerprint = try VoySyncEncoder.fingerprint(for: syncExport.document)
            let client = VoyServerClient(baseURL: baseURL, token: token)
            let status = try await client.status()

            if !force,
               status.current != nil,
               VoyServerConfiguration.lastFingerprint == fingerprint {
                state = .synced(VoyServerConfiguration.lastSyncDate ?? Date())
                return
            }

            let missingHashes = try await client.missingMedia(hashes: syncExport.document.media.map(\.hash))
            let missingObjects = syncExport.document.media.filter { missingHashes.contains($0.hash) }
            for (index, media) in missingObjects.enumerated() {
                state = .syncing("Uploading photo \(index + 1) of \(missingObjects.count)")
                guard let data = syncExport.mediaData[media.hash] else {
                    throw SyncError.missingLocalMedia(media.hash)
                }
                try await client.uploadMedia(hash: media.hash, data: data, contentType: media.contentType)
            }

            let snapshotID: UUID
            if VoyServerConfiguration.pendingFingerprint == fingerprint,
               let pending = VoyServerConfiguration.pendingSnapshotID {
                snapshotID = pending
            } else {
                snapshotID = UUID()
                VoyServerConfiguration.pendingFingerprint = fingerprint
                VoyServerConfiguration.pendingSnapshotID = snapshotID
            }

            state = .syncing("Saving snapshot")
            _ = try await client.uploadSnapshot(
                id: snapshotID,
                baseRevision: status.current?.revision,
                document: syncExport.document
            )
            let syncedAt = Date()
            VoyServerConfiguration.lastFingerprint = fingerprint
            VoyServerConfiguration.lastSyncDate = syncedAt
            VoyServerConfiguration.pendingFingerprint = nil
            VoyServerConfiguration.pendingSnapshotID = nil
            state = .synced(syncedAt)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

private enum SyncError: LocalizedError {
    case missingLocalMedia(String)

    var errorDescription: String? {
        switch self {
        case let .missingLocalMedia(hash):
            return "Photo \(hash.prefix(12)) could not be read during upload."
        }
    }
}
