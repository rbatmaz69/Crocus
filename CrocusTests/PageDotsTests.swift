import CoreGraphics
import Testing
@testable import Crocus

@Suite struct PageDotsTests {
    @Test func tokens() {
        #expect(CrocusMetrics.PageDots.dotSize == 6)
        #expect(CrocusMetrics.PageDots.spacing == 19)
        #expect(CrocusMetrics.PageDots.hitSize == 28)
    }

    @Test func rowWidth() {
        #expect(PageDotsLayout.rowWidth(count: 2) == 47)   // 19 + 28
        #expect(PageDotsLayout.rowWidth(count: 3) == 66)   // 2 × 19 + 28
        #expect(PageDotsLayout.rowWidth(count: 1) == 28)
    }

    @Test func dotCentres() {
        #expect(PageDotsLayout.centerX(of: 0) == 14)
        #expect(PageDotsLayout.centerX(of: 1) == 33)
        #expect(PageDotsLayout.centerX(of: 2) == 52)
    }

    @Test(arguments: [2, 3, 5])
    func eachCentreHitsItsDot(count: Int) {
        for dot in 0..<count {
            #expect(PageDotsLayout.index(at: PageDotsLayout.centerX(of: dot), count: count) == dot)
        }
    }

    @Test func nearestDotWins() {
        #expect(PageDotsLayout.index(at: 23, count: 3) == 0)  // 9 pt right of dot 0
        #expect(PageDotsLayout.index(at: 24, count: 3) == 1)  // 9 pt left of dot 1
        #expect(PageDotsLayout.index(at: 42, count: 3) == 1)
        #expect(PageDotsLayout.index(at: 43, count: 3) == 2)
    }

    @Test func clampsAtTheEnds() {
        #expect(PageDotsLayout.index(at: -10, count: 3) == 0)
        #expect(PageDotsLayout.index(at: 0, count: 3) == 0)
        #expect(PageDotsLayout.index(at: 66, count: 3) == 2)
        #expect(PageDotsLayout.index(at: 500, count: 3) == 2)
        #expect(PageDotsLayout.index(at: 10, count: 0) == 0)
    }
}
