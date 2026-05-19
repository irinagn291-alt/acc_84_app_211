import Foundation

struct OFFProductResponseDTO: Decodable, Sendable {
    let code: String?
    let status: Int?
    let product: OFFProductDTO?
}

struct OFFProductDTO: Decodable, Sendable {
    let code: String?
    let productName: String?
    let genericName: String?
    let brands: String?
    let quantity: String?
    let categoriesTags: [String]?
    let countriesTags: [String]?
    let imageUrl: String?
    let imageFrontUrl: String?
    let ingredientsText: String?
    let allergensTags: [String]?
    let tracesTags: [String]?
    let additivesTags: [String]?
    let nutriscoreGrade: String?
    let novaGroup: OFFFlexibleInt?
    let ecoscoreGrade: String?
    let nutriments: [String: OFFLooseNutrimentValue]?
    let labelsTags: [String]?
    let packagingTags: [String]?
    let packagingText: String?
    let stores: String?
    let storesTags: [String]?
    let link: String?
    let manufacturingPlaces: String?
    let origins: String?
    let brandsTags: [String]?
    let ingredientsFromPalmOilTags: [String]?
    let ingredientsThatMayBeFromPalmOilTags: [String]?
    let ingredientsAnalysisTags: [String]?
    let veganTags: [String]?
    let vegetarianTags: [String]?
}

struct OFFSearchResponseDTO: Decodable, Sendable {
    let hits: [OFFSearchHitDTO]
    let count: Int?
    let page: Int?
    let pageSize: Int?
    let pageCount: Int?
}

struct OFFSearchHitDTO: Decodable, Sendable {
    let code: String?
    let productName: String?
    let productNameEn: String?
    let imageFrontUrl: String?
    let nutriscoreGrade: String?
    let nutritionGrades: String?
    let brands: OFFFlexibleBrandsList?
    let nutriments: OFFLooseNutrimentsDict?
}

struct OFFFlexibleBrandsList: Decodable, Sendable {
    let entries: [String]

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) {
            entries = s.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            return
        }
        if let a = try? c.decode([String].self) {
            entries = a
            return
        }
        entries = []
    }
}

struct OFFLooseNutrimentsDict: Decodable, Sendable {
    let values: [String: Double]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: OFFNutrimentsDynamicKey.self)
        var out: [String: Double] = [:]
        for key in container.allKeys {
            if let d = try? container.decode(Double.self, forKey: key) {
                out[key.stringValue] = d
            } else if let i = try? container.decode(Int.self, forKey: key) {
                out[key.stringValue] = Double(i)
            } else if let s = try? container.decode(String.self, forKey: key),
                      let d = Double(s.replacingOccurrences(of: ",", with: "."))
            {
                out[key.stringValue] = d
            }
        }
        values = out
    }

    private struct OFFNutrimentsDynamicKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }
}

enum OFFFlexibleInt: Decodable, Sendable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Int.self) {
            self = .int(v)
            return
        }
        if let s = try? c.decode(String.self), let v = Int(s) {
            self = .int(v)
            return
        }
        self = .int(0)
    }

    var value: Int {
        switch self {
        case let .int(i): i
        case let .string(s): Int(s) ?? 0
        }
    }
}

struct OFFLooseNutrimentValue: Decodable, Sendable {
    let value: Double?

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Double.self) {
            value = v
            return
        }
        if let v = try? c.decode(Int.self) {
            value = Double(v)
            return
        }
        if let s = try? c.decode(String.self) {
            value = Double(s.replacingOccurrences(of: ",", with: "."))
            return
        }
        value = nil
    }
}

enum VerdantOFFMapper {
    static func mapProduct(dto: OFFProductDTO, fallbackBarcode: String) -> VerdantFoodItem {
        let code = dto.code ?? fallbackBarcode
        let name = dto.productName?.trimmingCharacters(in: .whitespacesAndNewlines).vpNilIfEmpty
            ?? dto.genericName?.trimmingCharacters(in: .whitespacesAndNewlines).vpNilIfEmpty
            ?? "Untitled"
        let brands = dto.brands?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
            .vpNilIfEmpty

        let n = dto.nutriments ?? [:]
        func g(_ keys: String...) -> Double? {
            for k in keys {
                if let v = n[k]?.value { return v }
            }
            return nil
        }
        let nutriments = VerdantNutriments(
            energyKcal100g: g("energy-kcal_100g", "energy_kcal_100g"),
            proteins100g: g("proteins_100g"),
            fat100g: g("fat_100g"),
            saturatedFat100g: g("saturated-fat_100g", "saturated_fat_100g"),
            carbohydrates100g: g("carbohydrates_100g"),
            sugars100g: g("sugars_100g"),
            fiber100g: g("fiber_100g"),
            salt100g: g("salt_100g"),
            sodium100g: g("sodium_100g")
        )

        let palm = !(dto.ingredientsFromPalmOilTags ?? []).isEmpty
            || !(dto.ingredientsThatMayBeFromPalmOilTags ?? []).isEmpty
            || (dto.ingredientsAnalysisTags ?? []).contains { $0.contains(VPRuntimeLexicon.palmOilMarker) }

        let packagingList: [String] = {
            if let p = dto.packagingTags, !p.isEmpty { return p.map { cleanTag($0) } }
            if let t = dto.packagingText, !t.isEmpty { return [t] }
            return []
        }()

        let storeList: [String] = {
            var r: [String] = dto.storesTags ?? []
            if let s = dto.stores?.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }).filter({ !$0.isEmpty }) {
                r.append(contentsOf: s.map { String($0) })
            }
            return Array(Set(r))
        }()

        return VerdantFoodItem(
            barcode: code,
            name: name,
            genericName: dto.genericName,
            brand: brands,
            quantity: dto.quantity,
            categories: dto.categoriesTags?.map(cleanTag) ?? [],
            countries: dto.countriesTags?.map(cleanTag) ?? [],
            imageUrl: dto.imageFrontUrl ?? dto.imageUrl,
            ingredientsText: dto.ingredientsText,
            allergens: dto.allergensTags?.map(cleanTag) ?? [],
            traces: dto.tracesTags?.map(cleanTag) ?? [],
            additives: dto.additivesTags?.map(cleanTag) ?? [],
            nutriScore: dto.nutriscoreGrade?.lowercased(),
            novaGroup: dto.novaGroup?.value,
            ecoScore: dto.ecoscoreGrade?.lowercased(),
            nutriments: nutriments,
            labels: dto.labelsTags?.map(cleanTag) ?? [],
            packaging: packagingList,
            stores: storeList,
            url: dto.link,
            manufacturingPlaces: dto.manufacturingPlaces,
            origins: dto.origins,
            brandsTags: dto.brandsTags?.map(cleanTag) ?? [],
            palmOilIngredients: palm,
            veganTags: dto.veganTags?.map(cleanTag) ?? [],
            vegetarianTags: dto.vegetarianTags?.map(cleanTag) ?? []
        )
    }

    static func mapSearch(dto: OFFSearchResponseDTO, page: Int, pageSize: Int) -> VerdantSearchPage {
        let items: [VerdantListItem] = dto.hits.compactMap { hit in
            let code = hit.code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !code.isEmpty else { return nil }
            let rawName = (hit.productName ?? hit.productNameEn ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let name = rawName.vpNilIfEmpty ?? "Untitled"
            let brand = hit.brands?.entries.first
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .flatMap { $0.vpNilIfEmpty }
            let n = hit.nutriments?.values ?? [:]
            func gv(_ keys: String...) -> Double? {
                for k in keys {
                    if let v = n[k] { return v }
                }
                return nil
            }
            let grade = (hit.nutriscoreGrade ?? hit.nutritionGrades)?.lowercased()
            return VerdantListItem(
                barcode: code,
                name: name,
                brand: brand,
                imageUrl: hit.imageFrontUrl,
                nutriScore: grade,
                energyKcal100g: gv("energy-kcal_100g", "energy_kcal_100g"),
                sugars100g: gv("sugars_100g"),
                salt100g: gv("salt_100g")
            )
        }
        let total = dto.count ?? items.count
        let pageCount = max(dto.pageCount ?? 1, 1)
        let hasMore = page < pageCount
        return VerdantSearchPage(items: items, totalCount: total, page: page, pageSize: pageSize, hasMore: hasMore)
    }

    static func listItem(from item: VerdantFoodItem) -> VerdantListItem {
        VerdantListItem(
            barcode: item.barcode,
            name: item.name,
            brand: item.brand,
            imageUrl: item.imageUrl,
            nutriScore: item.nutriScore,
            energyKcal100g: item.nutriments.energyKcal100g,
            sugars100g: item.nutriments.sugars100g,
            salt100g: item.nutriments.salt100g
        )
    }

    private static func cleanTag(_ raw: String) -> String {
        raw.replacingOccurrences(of: "^[a-z]{2}:", with: "", options: .regularExpression)
    }
}

private extension String {
    var vpNilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

private extension Optional where Wrapped == String {
    var vpNilIfEmpty: String? {
        guard let s = self else { return nil }
        return s.vpNilIfEmpty
    }
}
