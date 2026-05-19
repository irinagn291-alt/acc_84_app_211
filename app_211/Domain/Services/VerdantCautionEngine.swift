import Foundation

struct VerdantCautionRuleSet: Codable, Sendable, Equatable {
    var highSugarThresholdG: Double
    var highSaltThresholdG: Double
    var highSaturatedFatThresholdG: Double
    var highSugarMessage: String
    var highSaltMessage: String
    var highSaturatedFatMessage: String
    var ultraProcessedMessage: String
    var palmOilMessage: String

    static func loadFromBundle() -> VerdantCautionRuleSet {
        guard let data = VPRuntimeLexicon.cautionRulesJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(VerdantCautionRuleSet.self, from: data)
        else {
            preconditionFailure("Embedded caution rules payload is invalid")
        }
        return decoded
    }
}

struct VerdantCautionEngine {
    private let rules: VerdantCautionRuleSet

    init(rules: VerdantCautionRuleSet = .loadFromBundle()) {
        self.rules = rules
    }

    func evaluate(item: VerdantFoodItem) -> [VerdantCaution] {
        var result: [VerdantCaution] = []
        let n = item.nutriments

        if let s = n.sugars100g, s > rules.highSugarThresholdG {
            result.append(VerdantCaution(kind: .highSugar, severity: .caution, message: rules.highSugarMessage))
        }
        if let s = n.salt100g, s > rules.highSaltThresholdG {
            result.append(VerdantCaution(kind: .highSalt, severity: .caution, message: rules.highSaltMessage))
        }
        if let f = n.saturatedFat100g, f > rules.highSaturatedFatThresholdG {
            result.append(VerdantCaution(kind: .highSaturatedFat, severity: .caution, message: rules.highSaturatedFatMessage))
        }
        if item.novaGroup == 4 {
            result.append(VerdantCaution(kind: .ultraProcessed, severity: .caution, message: rules.ultraProcessedMessage))
        }
        if item.palmOilIngredients {
            result.append(VerdantCaution(kind: .palmOil, severity: .info, message: rules.palmOilMessage))
        }
        return result
    }
}
