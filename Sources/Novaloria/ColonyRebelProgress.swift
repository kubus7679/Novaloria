import FreeColGame
import Foundation

/// Values shown by FreeCol's original rebel tooltip.
struct ColonyRebelProgress: Equatable {
    let population: Int
    let rebels: Int
    let rebelPercentage: Int
    let royalists: Int
    let royalistPercentage: Int
    let libertyRemainder: Int
    let libertyProductionPerTurn: Int
    let progressRatePerTurn: Int
    let progressBarTurns: Int?
    let turnsUntilRebelGrowth: Int?
    let turnsTo50Percent: Int?
    let turnsTo100Percent: Int?
    let colonistsToAdd: Int

    static let libertyPerRebel = 200
    private static let maximumProjectionTurns = 1_000_000

    static func calculate(
        population: Int,
        liberty: Int,
        sonsOfLiberty: Int,
        libertyProductionPerTurn: Int,
        bellAccumulationCapped: Bool = false,
        rules: ColonyGovernmentRules,
        modifiers: [ColonyLibertyModifier],
        productionForBonus: (Int) -> Int
    ) -> ColonyRebelProgress? {
        guard population > 0 else { return nil }

        let rebels = rebelCount(population: population, sonsOfLiberty: sonsOfLiberty)
        let effectiveProduction = bellAccumulationCapped && sonsOfLiberty >= 100
            ? 0 : max(0, libertyProductionPerTurn)
        let remainder = ((liberty % libertyPerRebel) + libertyPerRebel) % libertyPerRebel
        let barTurns = effectiveProduction > 0
            ? (libertyPerRebel - remainder + effectiveProduction - 1) / effectiveProduction
            : nil

        let projections = projectedTurns(
            population: population,
            liberty: liberty,
            currentRebelCount: rebels,
            libertyProduction: effectiveProduction,
            rules: rules,
            modifiers: modifiers,
            productionForBonus: productionForBonus
        )
        let colonistsToAdd = colonistsThatPreserveGovernment(
            population: population,
            liberty: liberty,
            sonsOfLiberty: sonsOfLiberty,
            rules: rules,
            modifiers: modifiers
        )

        return ColonyRebelProgress(
            population: population,
            rebels: rebels,
            rebelPercentage: sonsOfLiberty,
            royalists: population - rebels,
            royalistPercentage: 100 - sonsOfLiberty,
            libertyRemainder: remainder,
            libertyProductionPerTurn: max(0, libertyProductionPerTurn),
            progressRatePerTurn: effectiveProduction,
            progressBarTurns: barTurns,
            turnsUntilRebelGrowth: projections.rebelGrowth,
            turnsTo50Percent: projections.goodGovernment,
            turnsTo100Percent: projections.veryGoodGovernment,
            colonistsToAdd: colonistsToAdd
        )
    }

    static func rebelCount(population: Int, sonsOfLiberty: Int) -> Int {
        Int(floor(Double(max(0, population)) * Double(sonsOfLiberty) / 100))
    }

    static func sonsOfLibertyPercent(
        population: Int,
        liberty: Int,
        modifiers: [ColonyLibertyModifier]
    ) -> Int {
        guard population > 0 else { return -1 }
        var membership = Double(liberty) * 100 / Double(libertyPerRebel * population)
        for modifier in modifiers.sorted(by: { $0.index < $1.index }) {
            switch modifier.kind {
            case .additive:
                membership += modifier.value
            case .multiplicative:
                membership *= modifier.value
            case .percentage:
                membership += membership * modifier.value / 100
            }
        }
        return Int(min(100, max(0, membership)))
    }

    static func governmentBonus(
        population: Int,
        sonsOfLiberty: Int,
        rules: ColonyGovernmentRules
    ) -> Int {
        if sonsOfLiberty >= rules.veryGoodGovernmentLimit { return 2 }
        if sonsOfLiberty >= rules.goodGovernmentLimit { return 1 }
        let tories = population - rebelCount(population: population, sonsOfLiberty: sonsOfLiberty)
        if tories > rules.veryBadGovernmentLimit { return -2 }
        if tories > rules.badGovernmentLimit { return -1 }
        return 0
    }

    private static func projectedTurns(
        population: Int,
        liberty: Int,
        currentRebelCount: Int,
        libertyProduction: Int,
        rules: ColonyGovernmentRules,
        modifiers: [ColonyLibertyModifier],
        productionForBonus: (Int) -> Int
    ) -> (rebelGrowth: Int?, goodGovernment: Int?, veryGoodGovernment: Int?) {
        guard libertyProduction > 0 else { return (nil, nil, nil) }

        var projectedLiberty = liberty
        var sonsOfLiberty = sonsOfLibertyPercent(
            population: population, liberty: projectedLiberty, modifiers: modifiers
        )
        var productionBonus = governmentBonus(
            population: population, sonsOfLiberty: sonsOfLiberty, rules: rules
        )
        var projectedProduction = libertyProduction
        var rebelGrowth: Int?
        var goodGovernment: Int?
        var veryGoodGovernment: Int?

        for turns in 0..<maximumProjectionTurns {
            let rebels = rebelCount(population: population, sonsOfLiberty: sonsOfLiberty)
            if rebels != currentRebelCount && rebelGrowth == nil {
                rebelGrowth = turns
            }
            if productionBonus == 1 && goodGovernment == nil {
                goodGovernment = turns
            }
            if productionBonus == 2 {
                if veryGoodGovernment == nil { veryGoodGovernment = turns }
                break
            }

            let nextLiberty = projectedLiberty + projectedProduction
            guard nextLiberty > projectedLiberty else { break }
            projectedLiberty = nextLiberty
            sonsOfLiberty = sonsOfLibertyPercent(
                population: population, liberty: projectedLiberty, modifiers: modifiers
            )
            let nextBonus = governmentBonus(
                population: population, sonsOfLiberty: sonsOfLiberty, rules: rules
            )
            if nextBonus != productionBonus {
                projectedProduction = max(0, productionForBonus(nextBonus))
            }
            productionBonus = nextBonus
        }

        // The native tooltip omits milestones already reached this turn.
        return (
            rebelGrowth,
            goodGovernment.flatMap { $0 > 0 ? $0 : nil },
            veryGoodGovernment.flatMap { $0 > 0 ? $0 : nil }
        )
    }

    private static func colonistsThatPreserveGovernment(
        population: Int,
        liberty: Int,
        sonsOfLiberty: Int,
        rules: ColonyGovernmentRules,
        modifiers: [ColonyLibertyModifier]
    ) -> Int {
        for additionalColonists in 1...10 {
            if governmentChange(
                currentPopulation: population,
                proposedPopulation: population + additionalColonists,
                liberty: liberty,
                currentSonsOfLiberty: sonsOfLiberty,
                rules: rules,
                modifiers: modifiers
            ) == -1 {
                return additionalColonists - 1
            }
        }
        return 10
    }

    /// Mirrors FreeCol's Colony.governmentChange for a proposed population.
    private static func governmentChange(
        currentPopulation: Int,
        proposedPopulation: Int,
        liberty: Int,
        currentSonsOfLiberty: Int,
        rules: ColonyGovernmentRules,
        modifiers: [ColonyLibertyModifier]
    ) -> Int {
        let newSonsOfLiberty = sonsOfLibertyPercent(
            population: proposedPopulation, liberty: liberty, modifiers: modifiers
        )
        let newTories = proposedPopulation
            - rebelCount(population: proposedPopulation, sonsOfLiberty: newSonsOfLiberty)
        let oldTories = currentPopulation
            - rebelCount(population: currentPopulation, sonsOfLiberty: currentSonsOfLiberty)

        if newSonsOfLiberty >= rules.veryGoodGovernmentLimit {
            return currentSonsOfLiberty < rules.veryGoodGovernmentLimit ? 1 : 0
        } else if newSonsOfLiberty >= rules.goodGovernmentLimit {
            if currentSonsOfLiberty >= rules.veryGoodGovernmentLimit { return -1 }
            return currentSonsOfLiberty < rules.goodGovernmentLimit ? 1 : 0
        } else if currentSonsOfLiberty >= rules.goodGovernmentLimit {
            return -1
        } else if newTories > rules.veryBadGovernmentLimit {
            return oldTories <= rules.veryBadGovernmentLimit ? -1 : 0
        } else if newTories > rules.badGovernmentLimit {
            if oldTories <= rules.badGovernmentLimit { return -1 }
            return oldTories > rules.veryBadGovernmentLimit ? 1 : 0
        } else {
            return oldTories > rules.badGovernmentLimit ? 1 : 0
        }
    }
}
