//
//  Digits.swift
//  BigInt
//
//  Created by Károly Lőrentey on 2015-12-27.
//  Copyright © 2016 Károly Lőrentey.
//

// これらはUInt64のためのプロトコルである(将来的にUInt128,UInt256がでても修正不要)
internal protocol BigDigit: UnsignedInteger, BitwiseOperations, ShiftOperations {
    // Intから生成できる
    init(_ v: Int)
    // UInt64の値一つからなる要素数1のArrayを生成できる
    // BigUIntはBigDigitの配列を要素として持つのでこのメソッドがあると便利
    static func digitsFromUIntMax(_ i: UIntMax) -> [Self]
    // ２つの値の掛け算(UInt64 * UInt64)の結果をlowとhighに分けて返せる
    static func fullMultiply(_ x: Self, _ y: Self) -> (high: Self, low: Self)
    // (high, low)をUInt64で割った商UInt64と剰余UInt64を返せる
    static func fullDivide(_ dividend: (high: Self, low: Self), _ divisor: Self) -> (div: Self, mod: Self)
    // 最大値(=2^64-1)
    static var max: Self { get }
    // UInt64の幅 つまり 64 
    static var width: Int { get }

    /// The number of leading zero bits in the binary representation of this digit.
    var leadingZeroes: Int { get }
    /// The number of trailing zero bits in the binary representation of this digit.
    var trailingZeroes: Int { get }

    // lowとhighを持つ
    var low: Self { get }
    var high: Self { get }
    // lowとhighに分けられる 
    var split: (high: Self, low: Self) { get }
}

extension BigDigit {
    var upshifted: Self { return self << (Self(Self.width) / 2) }

    init(high: Self, low: Self) {
        assert(low.high == 0 && high.high == 0)
        self = high.upshifted | low
    }
}

extension UInt64: BigDigit {
    internal static func digitsFromUIntMax(_ i: UIntMax) -> [UInt64] {
        return [i]
    }
}
 
//MARK: Full-width multiplication and division

extension BigDigit {
    /// Return a tuple with the high and low digits of the product of `x` and `y`.
    internal static func fullMultiply(_ x: Self, _ y: Self) -> (high: Self, low: Self) {
        let (a, b) = x.split
        let (c, d) = y.split

        // We don't have a full-width multiplication, so we build it out of four half-width multiplications.
        // x * y = ac * HH + (ad + bc) * H + bd where H = 2^(n/2)
        let (mv, mo) = Self.addWithOverflow(a * d, b * c)
        let (low, lo) = Self.addWithOverflow(b * d, mv.low.upshifted)
        let high = a * c + mv.high + (mo ? Self(1).upshifted : 0) + (lo ? 1 : 0)
        return (high, low)
    }

    /// Divide the two-digit number `(u1, u0)` by a single digit `v` and return the quotient and remainder.
    ///
    /// - Requires: `u1 < v`, so that the result will fit in a single digit.
    /// - Complexity: O(1) with 2 divisions, 6 multiplications and ~12 or so additions/subtractions.
    internal static func fullDivide(_ u: (high: Self, low: Self), _ v: Self) -> (div: Self, mod: Self) {
        // Division is complicated; doing it with single-digit operations is maddeningly complicated.
        // This is a Swift adaptation for "divlu2" in Hacker's Delight,
        // which is in turn a C adaptation of Knuth's Algorithm D (TAOCP vol 2, 4.3.1).
        precondition(u.high < v)

        /// Find the half-digit quotient in `(uh, ul) / vn`, which must be normalized.
        ///
        /// - Requires: uh < vn && ul.high == 0 && vn.width = width(Digit)
        func quotient(_ uh: Self, _ ul: Self, _ vn: Self) -> Self {
            let (vn1, vn0) = vn.split
            let q = uh / vn1 // Approximated quotient.
            let r = uh - q * vn1 // Remainder, less than vn1
            let p = q * vn0
            // q is often already correct, but sometimes the approximation overshoots by at most 2.
            // The code that follows checks for this while being careful to only perform single-digit operations.
            if q.high == 0 && p <= r.upshifted | ul { return q }
            if (r + vn1).high != 0 { return q - 1 }
            if (q - 1).high == 0 && (p - vn0) <= Self(high: r + vn1, low: ul) { return q - 1 }
            assert((r + 2 * vn1).high != 0 || p - 2 * vn0 <= Self(high: r + 2 * vn1, low: ul))
            return q - 2
        }
        /// Divide 3 half-digits by 2 half-digits to get a half-digit quotient and a full-digit remainder.
        ///
        /// - Requires: uh < vn && ul.high == 0 && vn.width = width(Digit)
        func divmod(_ uh: Self, _ ul: Self, _ v: Self) -> (div: Self, mod: Self) {
            let q = quotient(uh, ul, v)
            // Note that `uh.low` masks off a couple of bits, and `q * v` and the
            // subtraction are likely to overflow. Despite this, the end result (remainder) will
            // still be correct and it will fit inside a single (full) Digit.
            let r = Self(high: uh.low, low: ul) &- q &* v
            assert(r < v)
            return (q, r)
        }

        // Normalize u and v such that v has no leading zeroes.
        let z = Self(v.leadingZeroes)
        let w = Self(Self.width) - z
        let vn = v << z

        let un32 = (z == 0 ? u.high : (u.high << z) | (u.low >> w)) // No bits are lost
        let un10 = u.low << z
        let (un1, un0) = un10.split

        // Divide `(un32,un10)` by `vn`, splitting the full 4/2 division into two 3/2 ones.
        let (q1, un21) = divmod(un32, un1, vn)
        let (q0, rn) = divmod(un21, un0, vn)

        // Undo normalization of the remainder and combine the two halves of the quotient.
        let mod = rn >> z
        let div = Self(high: q1, low: q0)
        return (div, mod)
    }
}
