import Foundation
import SwiftData

@Model
final class VPSettingsRecord {
    @Attribute(.unique) var singletonKey: String
    var hasCompletedWelcome: Bool
    var openFoodFactsHost: String
    var useMetricUnits: Bool

    init(
        singletonKey: String = "vp_settings",
        hasCompletedWelcome: Bool = false,
        openFoodFactsHost: String = VerdantOFFRegion.world.host,
        useMetricUnits: Bool = true
    ) {
        self.singletonKey = singletonKey
        self.hasCompletedWelcome = hasCompletedWelcome
        self.openFoodFactsHost = openFoodFactsHost
        self.useMetricUnits = useMetricUnits
    }
}

@Model
final class VPCachedItemRecord {
    @Attribute(.unique) var barcode: String
    var payloadJSON: Data
    var cachedAt: Date

    init(barcode: String, payloadJSON: Data, cachedAt: Date = Date()) {
        self.barcode = barcode
        self.payloadJSON = payloadJSON
        self.cachedAt = cachedAt
    }
}

@Model
final class VPHistoryRecord {
    @Attribute(.unique) var barcode: String
    var name: String
    var brand: String?
    var imageUrl: String?
    var nutriScore: String?
    var viewedAt: Date

    init(barcode: String, name: String, brand: String?, imageUrl: String?, nutriScore: String?, viewedAt: Date = Date()) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.imageUrl = imageUrl
        self.nutriScore = nutriScore
        self.viewedAt = viewedAt
    }
}

@Model
final class VPFavoriteRecord {
    @Attribute(.unique) var barcode: String
    var name: String
    var brand: String?
    var imageUrl: String?
    var nutriScore: String?
    var savedAt: Date

    init(barcode: String, name: String, brand: String?, imageUrl: String?, nutriScore: String?, savedAt: Date = Date()) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.imageUrl = imageUrl
        self.nutriScore = nutriScore
        self.savedAt = savedAt
    }
}

@Model
final class VPBasketRecord {
    var id: UUID
    var day: Date
    var title: String
    @Relationship(deleteRule: .cascade) var items: [VPBasketItemRecord]

    init(id: UUID = UUID(), day: Date, title: String, items: [VPBasketItemRecord] = []) {
        self.id = id
        self.day = day
        self.title = title
        self.items = items
    }
}

@Model
final class VPBasketItemRecord {
    var barcode: String
    var name: String
    var brand: String?
    var imageUrl: String?
    var nutriScore: String?
    var sortOrder: Int

    init(barcode: String, name: String, brand: String?, imageUrl: String?, nutriScore: String?, sortOrder: Int = 0) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.imageUrl = imageUrl
        self.nutriScore = nutriScore
        self.sortOrder = sortOrder
    }
}
