import Foundation

struct VoyServerClient: Sendable {
    struct Status: Decodable, Sendable {
        struct Current: Decodable, Sendable {
            let revision: Int
        }

        let current: Current?
    }

    struct UploadResult: Decodable, Sendable {
        let revision: Int
        let snapshotId: UUID
    }

    enum ClientError: LocalizedError {
        case invalidResponse
        case server(status: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Voy Server returned an unreadable response."
            case let .server(status, message):
                return "Voy Server returned HTTP \(status): \(message)"
            }
        }
    }

    let baseURL: URL
    let token: String

    func status() async throws -> Status {
        let (data, _) = try await send(request(method: "GET", path: ["api", "v1", "status"]))
        return try VoySyncCoding.decoder().decode(Status.self, from: data)
    }

    func missingMedia(hashes: [String]) async throws -> Set<String> {
        var missing = Set<String>()
        for start in stride(from: 0, to: hashes.count, by: 1_000) {
            let end = min(start + 1_000, hashes.count)
            let body = try VoySyncCoding.encoder().encode(MissingMediaRequest(hashes: Array(hashes[start..<end])))
            let (data, _) = try await send(request(
                method: "POST",
                path: ["api", "v1", "media", "missing"],
                body: body,
                contentType: "application/json"
            ))
            missing.formUnion(try VoySyncCoding.decoder().decode(MissingMediaResponse.self, from: data).missing)
        }
        return missing
    }

    func uploadMedia(hash: String, data: Data, contentType: String) async throws {
        _ = try await send(request(
            method: "PUT",
            path: ["api", "v1", "media", hash],
            body: data,
            contentType: contentType
        ))
    }

    func uploadSnapshot(
        id: UUID,
        baseRevision: Int?,
        document: VoySyncDocument
    ) async throws -> UploadResult {
        let upload = SnapshotUpload(snapshotId: id, baseRevision: baseRevision, document: document)
        let body = try VoySyncCoding.encoder().encode(upload)
        let (data, _) = try await send(request(
            method: "PUT",
            path: ["api", "v1", "snapshot"],
            body: body,
            contentType: "application/json"
        ))
        return try VoySyncCoding.decoder().decode(UploadResult.self, from: data)
    }

    private func request(
        method: String,
        path: [String],
        body: Data? = nil,
        contentType: String? = nil
    ) -> URLRequest {
        let url = path.reduce(baseURL) { result, component in
            result.appendingPathComponent(component)
        }
        var request = URLRequest(url: url, timeoutInterval: 90)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let payload = try? VoySyncCoding.decoder().decode(ErrorPayload.self, from: data)
            throw ClientError.server(status: http.statusCode, message: payload?.error ?? "Request failed.")
        }
        return (data, http)
    }
}

private struct MissingMediaRequest: Encodable {
    let hashes: [String]
}

private struct MissingMediaResponse: Decodable {
    let missing: [String]
}

private struct ErrorPayload: Decodable {
    let error: String
}

private struct SnapshotUpload: Encodable {
    let snapshotId: UUID
    let baseRevision: Int?
    let document: VoySyncDocument

    private enum CodingKeys: String, CodingKey {
        case snapshotId, baseRevision, document
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(snapshotId, forKey: .snapshotId)
        if let baseRevision {
            try container.encode(baseRevision, forKey: .baseRevision)
        } else {
            try container.encodeNil(forKey: .baseRevision)
        }
        try container.encode(document, forKey: .document)
    }
}
