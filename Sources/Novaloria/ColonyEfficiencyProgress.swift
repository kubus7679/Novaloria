import FreeColGame
import Foundation

struct ColonyEfficiencyPopulationBand: Identifiable, Equatable {
    let minimumPopulation: Int
    let maximumPopulation: Int
    let productionBonus: Int

    var id: String { "\(minimumPopulation)-\(maximumPopulation)-\(productionBonus)" }
}

struct ColonyEfficiencyProgress: Equatable {
    let currentLiberty: Int
    let currentProductionBonus: Int
    let nextProductionBonus: Int?
    let libertyUntilNextBonus: Int?
    let bellsPerTurn: Int
    let populationBands: [ColonyEfficiencyPopulationBand]

    static func calculate(
        population: Int,
        liberty: Int,
        currentProductionBonus: Int,
        bellsPerTurn: Int,
        rules: ColonyGovernmentRules,
        modifiers: [ColonyLibertyModifier]
    ) -> ColonyEfficiencyProgress? {
        guard population > 0 else { return nil }

        let bands = population...(population + 10)
        var populationBands: [ColonyEfficiencyPopulationBand] = []
        var bandStart = population
        var previousBonus: Int?

        for candidatePopulation in bands {
            // Use the authoritative server value for the current colony; the
            // projection is calculated locally only for other population sizes.
            let bonus = candidatePopulation == population
                ? currentProductionBonus
                : governmentBonus(
                    population: candidatePopulation,
                    liberty: liberty,
                    rules: rules,
                    modifiers: modifiers
                )

            if let previousBonus, previousBonus != bonus {
                populationBands.append(ColonyEfficiencyPopulationBand(
                    minimumPopulation: bandStart,
                    maximumPopulation: candidatePopulation - 1,
                    productionBonus: previousBonus
                ))
                bandStart = candidatePopulation
            }
            previousBonus = bonus
        }

        if let previousBonus {
            populationBands.append(ColonyEfficiencyPopulationBand(
                minimumPopulation: bandStart,
                maximumPopulation: population + 10,
                productionBonus: previousBonus
            ))
        }

        let next = nextEfficiencyThreshold(
            population: population,
            liberty: liberty,
            currentProductionBonus: currentProductionBonus,
            rules: rules,
            modifiers: modifiers
        )

        return ColonyEfficiencyProgress(
            currentLiberty: liberty,
            currentProductionBonus: currentProductionBonus,
            nextProductionBonus: next?.productionBonus,
            libertyUntilNextBonus: next.map { $0.liberty - liberty },
            bellsPerTurn: max(0, bellsPerTurn),
            populationBands: populationBands
        )
    }

    private static func nextEfficiencyThreshold(
        population: Int,
        liberty: Int,
        currentProductionBonus: Int,
        rules: ColonyGovernmentRules,
        modifiers: [ColonyLibertyModifier]
    ) -> (liberty: Int, productionBonus: Int)? {
        // All standard FreeCol liberty modifiers reach the 100% SoL cap by
        // this point. Use a population-scaled bound to avoid unbounded search.
        let upperBound = max(liberty + 1, population * 800)
        guard upperBound > liberty,
              governmentBonus(
                population: population,
                liberty: upperBound,
                rules: rules,
                modifiers: modifiers
              ) > currentProductionBonus else { return nil }

        var lower = liberty + 1
        var upper = upperBound
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            let bonus = governmentBonus(
                population: population,
                liberty: middle,
                rules: rules,
                modifiers: modifiers
            )
            if bonus > currentProductionBonus {
                upper = middle
            } else {
                lower = middle + 1
            }
        }
        return (lower, governmentBonus(
            population: population,
            liberty: lower,
            rules: rules,
            modifiers: modifiers
        ))
    }

    private static func governmentBonus(
        population: Int,
        liberty: Int,
        rules: ColonyGovernmentRules,
        modifiers: [ColonyLibertyModifier]
    ) -> Int {
        guard population > 0 else { return 0 }
        var percentage = Double(liberty) * 100 / Double(200 * population)
        for modifier in modifiers.sorted(by: { $0.index < $1.index }) {
            switch modifier.kind {
            case .additive:
                percentage += modifier.value
            case .multiplicative:
                percentage *= modifier.value
            case .percentage:
                percentage += percentage * modifier.value / 100
            }
        }
        let sonsOfLiberty = Int(min(100, max(0, percentage)))
        let rebels = sonsOfLiberty * population / 100
        let tories = population - rebels

        if sonsOfLiberty >= rules.veryGoodGovernmentLimit { return 2 }
        if sonsOfLiberty >= rules.goodGovernmentLimit { return 1 }
        if tories > rules.veryBadGovernmentLimit { return -2 }
        if tories > rules.badGovernmentLimit { return -1 }
        return 0
    }
}
