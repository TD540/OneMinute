//
//  Flood.swift
//  OneMinute
//

import SwiftUI

/// A color that floods out from a point until it covers the view, and drains back into it.
struct Flood: View {
    var isFilled: Bool
    var origin: CGPoint
    var color: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // Just large enough to reach the corner farthest from the origin.
            let radius = [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
                .map { hypot($0.x - origin.x, $0.y - origin.y) }
                .max() ?? 0
            Circle()
                .fill(color)
                .frame(width: radius * 2, height: radius * 2)
                .scaleEffect(isFilled ? 1 : 0.001)
                .position(origin)
        }
        .allowsHitTesting(false)
    }
}
