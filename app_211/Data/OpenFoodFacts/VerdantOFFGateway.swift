import Foundation

enum VerdantOFFGatewayError: Error, Sendable {
    case invalidResponse
    case httpStatus(Int)
    case productMissing
    case decoding
}

final class VerdantOFFGateway {
    private let session: URLSession
    private let jsonDecoder: JSONDecoder

    init(session: URLSession? = nil) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 45
        self.session = session ?? URLSession(configuration: config)
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        self.jsonDecoder = dec
    }

    func fetchProduct(host: String, barcode: String) async throws -> VerdantFoodItem {
        let urlString = VPRuntimeLexicon.httpsPrefix + host + VPRuntimeLexicon.productPathPrefix + barcode + VPRuntimeLexicon.jsonSuffix
        guard let url = URL(string: urlString) else {
            throw VerdantOFFGatewayError.invalidResponse
        }
        let data = try await get(url: url)
        let dto = try jsonDecoder.decode(OFFProductResponseDTO.self, from: data)
        guard let p = dto.product else {
            throw VerdantOFFGatewayError.productMissing
        }
        if dto.status == 0 {
            throw VerdantOFFGatewayError.productMissing
        }
        return VerdantOFFMapper.mapProduct(dto: p, fallbackBarcode: barcode)
    }

    func search(query: String, page: Int, pageSize: Int) async throws -> VerdantSearchPage {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            return VerdantSearchPage(items: [], totalCount: 0, page: page, pageSize: pageSize, hasMore: false)
        }
        var c = URLComponents(string: VPRuntimeLexicon.searchEndpoint)!
        c.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "page", value: String(page)),
        ]
        guard let url = c.url else {
            throw VerdantOFFGatewayError.invalidResponse
        }
        let data = try await get(url: url)
        let dto = try jsonDecoder.decode(OFFSearchResponseDTO.self, from: data)
        return VerdantOFFMapper.mapSearch(dto: dto, page: page, pageSize: pageSize)
    }

    private func get(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(VPRuntimeLexicon.userAgentValue, forHTTPHeaderField: VPRuntimeLexicon.userAgentHeaderField)
        request.setValue(VPRuntimeLexicon.acceptHeaderValue, forHTTPHeaderField: VPRuntimeLexicon.acceptHeaderField)

        var lastError: Error?
        for attempt in 0 ..< 2 {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw VerdantOFFGatewayError.invalidResponse
                }
                if (500 ... 599).contains(http.statusCode), attempt == 0 {
                    continue
                }
                guard (200 ... 299).contains(http.statusCode) else {
                    throw VerdantOFFGatewayError.httpStatus(http.statusCode)
                }
                return data
            } catch {
                lastError = error
                if attempt == 0, shouldRetry(error: error) {
                    continue
                }
                throw error
            }
        }
        throw lastError ?? VerdantOFFGatewayError.invalidResponse
    }

    private func shouldRetry(error: Error) -> Bool {
        if let urlErr = error as? URLError {
            switch urlErr.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }
        return false
    }
}
