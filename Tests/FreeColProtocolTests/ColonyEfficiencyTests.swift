import XCTest
import FreeColGame
import FreeColProtocol
@testable import Novaloria

final class ColonyEfficiencyTests: XCTestCase {
    func testTooltipShowsRebelsRoyalistsAndLibertyBarProgress() throws {
        let progress = try XCTUnwrap(ColonyRebelProgress.calculate(
            population: 5,
            liberty: 400,
            sonsOfLiberty: 40,
            libertyProductionPerTurn: 20,
            rules: .classic,
            modifiers: [],
            productionForBonus: { _ in 20 }
        ))

        XCTAssertEqual(progress.rebels, 2)
        XCTAssertEqual(progress.rebelPercentage, 40)
        XCTAssertEqual(progress.royalists, 3)
        XCTAssertEqual(progress.royalistPercentage, 60)
        XCTAssertEqual(progress.libertyRemainder, 0)
        XCTAssertEqual(progress.libertyProductionPerTurn, 20)
        XCTAssertEqual(progress.progressBarTurns, 10)
    }

    func testTurnForecastRecalculatesBellProductionAfterGovernmentChanges() throws {
        let progress = try XCTUnwrap(ColonyRebelProgress.calculate(
            population: 5,
            liberty: 400,
            sonsOfLiberty: 40,
            libertyProductionPerTurn: 20,
            rules: .classic,
            modifiers: [],
            productionForBonus: { bonus in bonus == 1 ? 10 : 20 }
        ))

        XCTAssertEqual(progress.turnsTo50Percent, 5)
        XCTAssertEqual(progress.turnsUntilRebelGrowth, 15)
        XCTAssertEqual(progress.turnsTo100Percent, 55)
    }

    func testTooltipReportsColonistsThatCanBeAddedWithoutLosingEfficiency() throws {
        let progress = try XCTUnwrap(ColonyRebelProgress.calculate(
            population: 5,
            liberty: 900,
            sonsOfLiberty: 90,
            libertyProductionPerTurn: 20,
            rules: .classic,
            modifiers: [],
            productionForBonus: { _ in 20 }
        ))

        XCTAssertEqual(progress.colonistsToAdd, 4)
    }

    func testCappedBellAccumulationHidesProgressForecastAtOneHundredPercent() throws {
        let progress = try XCTUnwrap(ColonyRebelProgress.calculate(
            population: 5,
            liberty: 1_000,
            sonsOfLiberty: 100,
            libertyProductionPerTurn: 20,
            bellAccumulationCapped: true,
            rules: .classic,
            modifiers: [],
            productionForBonus: { _ in 20 }
        ))

        XCTAssertEqual(progress.libertyProductionPerTurn, 20)
        XCTAssertEqual(progress.progressRatePerTurn, 0)
        XCTAssertNil(progress.progressBarTurns)
        XCTAssertNil(progress.turnsUntilRebelGrowth)
        XCTAssertNil(progress.turnsTo50Percent)
        XCTAssertNil(progress.turnsTo100Percent)
    }

    func testSpecificationReadsActiveGovernmentRulesAndSoLModifiers() throws {
        let specification = Specification(parsed: try XMLDecoder.decode("""
        <freecol-specification difficulty-level="model.difficulty.medium">
          <optionGroup id="gameOptions.colony">
            <booleanOption id="model.option.bellAccumulationCapped" defaultValue="false"/>
          </optionGroup>
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
        XCTAssertFalse(specification.bellAccumulationCapped)
        XCTAssertEqual(
            specification.colonyLibertyModifiers(
                nationTypeId: "model.nationType.child",
                foundingFathers: ["model.foundingFather.simonBolivar"]
            ).map(\.value),
            [10, 20]
        )
    }
}
