import XCTest
import FreeColGame
import FreeColProtocol
@testable import Novaloria

final class ColonyEfficiencyTests: XCTestCase {
    func testNextProductionBonusReportsExactAdditionalLiberty() throws {
        let progress = try XCTUnwrap(ColonyEfficiencyProgress.calculate(
            population: 5,
            liberty: 0,
            currentProductionBonus: 0,
            bellsPerTurn: 4,
            rules: .classic,
            modifiers: []
        ))

        XCTAssertEqual(progress.nextProductionBonus, 1)
        XCTAssertEqual(progress.libertyUntilNextBonus, 500)
        XCTAssertEqual(progress.bellsPerTurn, 4)
    }

    func testLibertyModifiersAffectNextBonusThreshold() throws {
        let progress = try XCTUnwrap(ColonyEfficiencyProgress.calculate(
            population: 5,
            liberty: 300,
            currentProductionBonus: 1,
            bellsPerTurn: 2,
            rules: .classic,
            modifiers: [ColonyLibertyModifier(kind: .additive, value: 20, index: 100)]
        ))

        XCTAssertEqual(progress.nextProductionBonus, 2)
        XCTAssertEqual(progress.libertyUntilNextBonus, 500)
    }

    func testPopulationBandsShowEfficiencyAtCurrentLiberty() throws {
        let progress = try XCTUnwrap(ColonyEfficiencyProgress.calculate(
            population: 5,
            liberty: 1_000,
            currentProductionBonus: 2,
            bellsPerTurn: 0,
            rules: .classic,
            modifiers: []
        ))

        XCTAssertEqual(progress.populationBands, [
            ColonyEfficiencyPopulationBand(minimumPopulation: 5, maximumPopulation: 5, productionBonus: 2),
            ColonyEfficiencyPopulationBand(minimumPopulation: 6, maximumPopulation: 10, productionBonus: 1),
            ColonyEfficiencyPopulationBand(minimumPopulation: 11, maximumPopulation: 12, productionBonus: 0),
            ColonyEfficiencyPopulationBand(minimumPopulation: 13, maximumPopulation: 15, productionBonus: -1),
        ])
        XCTAssertNil(progress.nextProductionBonus)
        XCTAssertNil(progress.libertyUntilNextBonus)
    }

    func testSpecificationReadsActiveGovernmentRulesAndSoLModifiers() throws {
        let specification = Specification(parsed: try XMLDecoder.decode("""
        <freecol-specification difficulty-level="model.difficulty.medium">
          <optionGroup id="model.difficulty.medium">
            <optionGroup id="model.difficulty.government">
              <integerOption id="model.option.badGovernmentLimit" value="6"/>
              <integerOption id="model.option.veryBadGovernmentLimit" value="10"/>
              <integerOption id="model.option.goodGovernmentLimit" value="55"/>
              <integerOption id="model.option.veryGoodGovernmentLimit" value="95"/>
            </optionGroup>
          </optionGroup>
          <founding-fathers>
            <founding-father id="model.foundingFather.simonBolivar">
              <modifier id="model.modifier.SoL" index="20" type="additive" value="20"/>
            </founding-father>
          </founding-fathers>
          <european-nation-types>
            <european-nation-type id="model.nationType.parent">
              <modifier id="model.modifier.SoL" index="10" type="percentage" value="10"/>
            </european-nation-type>
            <european-nation-type id="model.nationType.child" extends="model.nationType.parent"/>
          </european-nation-types>
        </freecol-specification>
        """))

        XCTAssertEqual(specification.colonyGovernmentRules.badGovernmentLimit, 6)
        XCTAssertEqual(specification.colonyGovernmentRules.veryBadGovernmentLimit, 10)
        XCTAssertEqual(specification.colonyGovernmentRules.goodGovernmentLimit, 55)
        XCTAssertEqual(specification.colonyGovernmentRules.veryGoodGovernmentLimit, 95)
        XCTAssertEqual(
            specification.colonyLibertyModifiers(
                nationTypeId: "model.nationType.child",
                foundingFathers: ["model.foundingFather.simonBolivar"]
            ).map(\.value),
            [10, 20]
        )
    }
}
