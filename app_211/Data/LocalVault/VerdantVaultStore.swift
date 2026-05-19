import Combine
import Foundation
import Network
import SwiftData

@MainActor
final class VerdantReachability: ObservableObject {
    @Published private(set) var isOnline = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.VerdantPlate.reachability")

    func begin() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

@MainActor
final class VerdantVaultStore {
    private let context: ModelContext
    private let gateway: VerdantOFFGateway
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let cacheDays = 7

    init(context: ModelContext, gateway: VerdantOFFGateway) {
        self.context = context
        self.gateway = gateway
    }

    // MARK: - Settings

    func fetchPrefs() throws -> VerdantPrefsSnapshot {
        let record = try ensureSettings()
        return VerdantPrefsSnapshot(
            hasCompletedWelcome: record.hasCompletedWelcome,
            openFoodFactsHost: record.openFoodFactsHost,
            useMetricUnits: record.useMetricUnits
        )
    }

    func savePrefs(_ prefs: VerdantPrefsSnapshot) throws {
        let record = try ensureSettings()
        record.hasCompletedWelcome = prefs.hasCompletedWelcome
        record.openFoodFactsHost = prefs.openFoodFactsHost
        record.useMetricUnits = prefs.useMetricUnits
        try context.save()
        NotificationCenter.default.post(name: .verdantPrefsChanged, object: nil)
    }

    private func ensureSettings() throws -> VPSettingsRecord {
        let key = "vp_settings"
        var desc = FetchDescriptor<VPSettingsRecord>(predicate: #Predicate { $0.singletonKey == key })
        desc.fetchLimit = 1
        if let existing = try context.fetch(desc).first {
            return existing
        }
        let record = VPSettingsRecord()
        context.insert(record)
        try context.save()
        return record
    }

    // MARK: - Product fetch

    func fetchItem(barcode: String, preferNetwork: Bool) async throws -> VerdantResolvedItem {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VerdantPlateError.invalidBarcode }

        let prefs = try fetchPrefs()
        let host = prefs.openFoodFactsHost

        if !preferNetwork, let cached = try loadCache(barcode: trimmed), !isExpired(cached.cachedAt) {
            return VerdantResolvedItem(item: cached.item, source: .cache)
        }

        do {
            let item = try await gateway.fetchProduct(host: host, barcode: trimmed)
            try saveCache(item: item)
            try recordHistory(item: item)
            return VerdantResolvedItem(item: item, source: .network)
        } catch {
            if let cached = try loadCache(barcode: trimmed) {
                return VerdantResolvedItem(item: cached.item, source: .cacheWhenOffline)
            }
            if case VerdantOFFGatewayError.productMissing = error {
                throw VerdantPlateError.itemNotFound
            }
            if error is DecodingError {
                throw VerdantPlateError.decodingFailed
            }
            if let url = error as? URLError, url.code == .notConnectedToInternet || url.code == .dataNotAllowed {
                throw VerdantPlateError.networkUnavailable
            }
            throw VerdantPlateError.networkUnavailable
        }
    }

    func search(query: String, page: Int, pageSize: Int = 20) async throws -> VerdantSearchPage {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else {
            return VerdantSearchPage(items: [], totalCount: 0, page: page, pageSize: pageSize, hasMore: false)
        }
        do {
            return try await gateway.search(query: q, page: page, pageSize: pageSize)
        } catch {
            if error is DecodingError { throw VerdantPlateError.decodingFailed }
            throw VerdantPlateError.networkUnavailable
        }
    }

    // MARK: - Cache

    private struct CachePair {
        var item: VerdantFoodItem
        var cachedAt: Date
    }

    private func isExpired(_ date: Date) -> Bool {
        let limit = Calendar.current.date(byAdding: .day, value: -cacheDays, to: Date()) ?? Date.distantPast
        return date < limit
    }

    private func loadCache(barcode: String) throws -> CachePair? {
        var desc = FetchDescriptor<VPCachedItemRecord>(predicate: #Predicate { $0.barcode == barcode })
        desc.fetchLimit = 1
        guard let e = try context.fetch(desc).first,
              let item = try? decoder.decode(VerdantFoodItem.self, from: e.payloadJSON)
        else { return nil }
        return CachePair(item: item, cachedAt: e.cachedAt)
    }

    private func saveCache(item: VerdantFoodItem) throws {
        let data = try encoder.encode(item)
        var desc = FetchDescriptor<VPCachedItemRecord>(predicate: #Predicate { $0.barcode == item.barcode })
        desc.fetchLimit = 1
        let e = try context.fetch(desc).first ?? VPCachedItemRecord(barcode: item.barcode, payloadJSON: data)
        e.barcode = item.barcode
        e.payloadJSON = data
        e.cachedAt = Date()
        if e.modelContext == nil { context.insert(e) }
        try context.save()
    }

    // MARK: - History

    func recordHistory(item: VerdantFoodItem) throws {
        var desc = FetchDescriptor<VPHistoryRecord>(predicate: #Predicate { $0.barcode == item.barcode })
        desc.fetchLimit = 1
        let e = try context.fetch(desc).first ?? VPHistoryRecord(
            barcode: item.barcode, name: item.name, brand: item.brand,
            imageUrl: item.imageUrl, nutriScore: item.nutriScore
        )
        e.name = item.name
        e.brand = item.brand
        e.imageUrl = item.imageUrl
        e.nutriScore = item.nutriScore
        e.viewedAt = Date()
        if e.modelContext == nil { context.insert(e) }
        try context.save()
    }

    func fetchHistory(limit: Int = 50, query: String = "") throws -> [VerdantHistoryEntry] {
        var desc = FetchDescriptor<VPHistoryRecord>(sortBy: [SortDescriptor(\.viewedAt, order: .reverse)])
        desc.fetchLimit = limit
        let rows = try context.fetch(desc)
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return rows.compactMap { e in
            if !q.isEmpty {
                let hay = "\(e.name) \(e.brand ?? "") \(e.barcode)".lowercased()
                guard hay.contains(q) else { return nil }
            }
            return VerdantHistoryEntry(
                barcode: e.barcode, name: e.name, brand: e.brand,
                imageUrl: e.imageUrl, nutriScore: e.nutriScore, viewedAt: e.viewedAt
            )
        }
    }

    func clearHistory() throws {
        try context.delete(model: VPHistoryRecord.self)
        try context.save()
    }

    // MARK: - Favorites

    func isFavorite(barcode: String) throws -> Bool {
        var desc = FetchDescriptor<VPFavoriteRecord>(predicate: #Predicate { $0.barcode == barcode })
        desc.fetchLimit = 1
        return try context.fetch(desc).first != nil
    }

    func toggleFavorite(item: VerdantFoodItem) throws -> Bool {
        var desc = FetchDescriptor<VPFavoriteRecord>(predicate: #Predicate { $0.barcode == item.barcode })
        desc.fetchLimit = 1
        if let existing = try context.fetch(desc).first {
            context.delete(existing)
            try context.save()
            return false
        }
        let e = VPFavoriteRecord(
            barcode: item.barcode, name: item.name, brand: item.brand,
            imageUrl: item.imageUrl, nutriScore: item.nutriScore
        )
        context.insert(e)
        try context.save()
        return true
    }

    func fetchFavorites(query: String = "") throws -> [VerdantListItem] {
        var desc = FetchDescriptor<VPFavoriteRecord>(sortBy: [SortDescriptor(\.savedAt, order: .reverse)])
        let rows = try context.fetch(desc)
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return rows.compactMap { e in
            if !q.isEmpty {
                let hay = "\(e.name) \(e.brand ?? "") \(e.barcode)".lowercased()
                guard hay.contains(q) else { return nil }
            }
            return VerdantListItem(
                barcode: e.barcode, name: e.name, brand: e.brand,
                imageUrl: e.imageUrl, nutriScore: e.nutriScore,
                energyKcal100g: nil, sugars100g: nil, salt100g: nil
            )
        }
    }

    // MARK: - Baskets

    func fetchBaskets() throws -> [VerdantBasket] {
        let desc = FetchDescriptor<VPBasketRecord>(sortBy: [SortDescriptor(\.day, order: .forward)])
        return try context.fetch(desc).map { basket in
            let items = basket.items.sorted { $0.sortOrder < $1.sortOrder }.map {
                VerdantListItem(
                    barcode: $0.barcode, name: $0.name, brand: $0.brand,
                    imageUrl: $0.imageUrl, nutriScore: $0.nutriScore,
                    energyKcal100g: nil, sugars100g: nil, salt100g: nil
                )
            }
            return VerdantBasket(id: basket.id, day: basket.day, title: basket.title, items: items)
        }
    }

    func ensureBasket(for day: Date) throws -> VerdantBasket {
        let dayStart = Calendar.current.startOfDay(for: day)
        var desc = FetchDescriptor<VPBasketRecord>()
        let all = try context.fetch(desc)
        if let existing = all.first(where: { Calendar.current.isDate($0.day, inSameDayAs: dayStart) }) {
            return VerdantBasket(
                id: existing.id, day: existing.day, title: existing.title,
                items: existing.items.sorted { $0.sortOrder < $1.sortOrder }.map {
                    VerdantListItem(barcode: $0.barcode, name: $0.name, brand: $0.brand,
                                    imageUrl: $0.imageUrl, nutriScore: $0.nutriScore,
                                    energyKcal100g: nil, sugars100g: nil, salt100g: nil)
                }
            )
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        let title = formatter.string(from: dayStart)
        let record = VPBasketRecord(day: dayStart, title: title)
        context.insert(record)
        try context.save()
        return VerdantBasket(id: record.id, day: record.day, title: record.title, items: [])
    }

    func addToBasket(day: Date, item: VerdantFoodItem) throws {
        let dayStart = Calendar.current.startOfDay(for: day)
        var desc = FetchDescriptor<VPBasketRecord>()
        let all = try context.fetch(desc)
        let basket = all.first(where: { Calendar.current.isDate($0.day, inSameDayAs: dayStart) })
            ?? {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMM d"
                let r = VPBasketRecord(day: dayStart, title: formatter.string(from: dayStart))
                context.insert(r)
                return r
            }()
        if basket.items.contains(where: { $0.barcode == item.barcode }) { return }
        let entry = VPBasketItemRecord(
            barcode: item.barcode, name: item.name, brand: item.brand,
            imageUrl: item.imageUrl, nutriScore: item.nutriScore,
            sortOrder: basket.items.count
        )
        basket.items.append(entry)
        try context.save()
    }

    func removeFromBasket(basketId: UUID, barcode: String) throws {
        var desc = FetchDescriptor<VPBasketRecord>(predicate: #Predicate { $0.id == basketId })
        desc.fetchLimit = 1
        guard let basket = try context.fetch(desc).first else { return }
        if let idx = basket.items.firstIndex(where: { $0.barcode == barcode }) {
            let item = basket.items.remove(at: idx)
            context.delete(item)
            try context.save()
        }
    }

    func deleteBasket(id: UUID) throws {
        var desc = FetchDescriptor<VPBasketRecord>(predicate: #Predicate { $0.id == id })
        desc.fetchLimit = 1
        if let basket = try context.fetch(desc).first {
            context.delete(basket)
            try context.save()
        }
    }

    func clearCache() throws {
        try context.delete(model: VPCachedItemRecord.self)
        try context.save()
    }

    func clearAllData() throws {
        try context.delete(model: VPCachedItemRecord.self)
        try context.delete(model: VPHistoryRecord.self)
        try context.delete(model: VPFavoriteRecord.self)
        try context.delete(model: VPBasketRecord.self)
        try context.save()
    }
}

extension Notification.Name {
    static let verdantPrefsChanged = Notification.Name("verdantPrefsChanged")
}
