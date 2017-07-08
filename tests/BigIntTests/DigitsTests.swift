//
//  DigitsTests.swift
//  BigInt
//
//  Created by Károly Lőrentey on 2015-12-27.
//  Copyright © 2016 Károly Lőrentey.
//

import XCTest
@testable import BigInt

class DigitsTests: XCTestCase {



    func testUInt64() {
        XCTAssertEqual(UInt64.width, 64)
        XCTAssertEqual(UInt64.digitsFromUIntMax(0x123456789ABCDEF0), [0x123456789ABCDEF0])
    }



    func testFullMultiply() {
        func test<Digit: BigDigit>(_: Digit) {
            var high, low: Digit

            (high, low) = Digit.fullMultiply(2, 3)
            XCTAssertEqual(low, 6)
            XCTAssertEqual(high, 0)

            (high, low) = Digit.fullMultiply(Digit.max, 2)
            XCTAssertEqual(low, Digit.max - 1)
            XCTAssertEqual(high, 1)

            (high, low) = Digit.fullMultiply(Digit(1).upshifted, 2)
            XCTAssertEqual(low, Digit(1).upshifted * 2)
            XCTAssertEqual(high, 0)

            (high, low) = Digit.fullMultiply(2, Digit(1).upshifted)
            XCTAssertEqual(low, Digit(1).upshifted * 2)
            XCTAssertEqual(high, 0)

            (high, low) = Digit.fullMultiply(Digit.max, Digit.max)
            XCTAssertEqual(low, 1)
            XCTAssertEqual(high, Digit.max - 1)

            let half = Digit.max.low
            (high, low) = Digit.fullMultiply(half.upshifted, half)
            XCTAssertEqual(low, Digit(1).upshifted)
            XCTAssertEqual(high, half - 1)
            
            (high, low) = Digit.fullMultiply(half, half.upshifted)
            XCTAssertEqual(low, Digit(1).upshifted)
            XCTAssertEqual(high, half - 1)
        }
        test(UInt64(0))
        /*
        test(UInt32(0))
        test(UInt16(0))
        test(UInt8(0))
 */
    }
}

struct TestDivision<Digit: BigDigit> {
    static func testDivision(_ u: (high: Digit, low: Digit), _ v: Digit) {
        let (div, mod) = Digit.fullDivide(u, v)
        var (ph, pl) = Digit.fullMultiply(div, v)
        let (s, o) = Digit.addWithOverflow(pl, mod)
        pl = s
        if o { ph += Digit(1) }

        if mod >= v {
            XCTFail("For u = \(u), v = \(v): u mod v = \(mod), which is greater than v")
        }

        XCTAssertEqual(ph, u.high, "For u = \(u), v = \(v), u div v = \(div), u mod v = \(mod), but div * v + mod = \((ph, pl))")
        XCTAssertEqual(pl, u.low, "For u = \(u), v = \(v), u div v = \(div), u mod v = \(mod), but div * v + mod = \((ph, pl))")
    }


    static func test() {
        testDivision((0, 0), 2)
        testDivision((0, 1), 2)
        testDivision((1, 0), 2)
        testDivision((8, 0), 136)
        testDivision((128, 0), 136)
        testDivision((2, 0), 35)
        testDivision((7, 12), 19)
    }
}

extension DigitsTests {
    func testFullDivide() {
        TestDivision<UInt64>.test()
        /*
        TestDivision<UInt32>.test()
        TestDivision<UInt16>.test()
        TestDivision<UInt8>.test()
 */

        #if false && TinyDigits
            for v in (0..<Digit.max).map({ $0 + 1 }) {
                for u1 in 0..<v {
                    for u0 in 0...Digit.max.low {
                        testDivision((u1, u0), v)
                    }
                }
            }
        #endif
    }
}
