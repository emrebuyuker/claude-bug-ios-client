//
//  CGSize+Extensions.swift
//  ClaudeBugPoC
//

import CoreGraphics

extension CGSize {

    /// Returns width or height, whichever is the bigger value.
    var maxDimension: CGFloat {
        return max(width, height)
    }

    /// Returns width or height, whichever is the smaller value.
    var minDimension: CGFloat {
        return min(width, height)
    }
}
