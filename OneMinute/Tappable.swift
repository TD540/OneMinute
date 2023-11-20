//
//  Tappable.swift
//  OneMinute
//
//  Created by thomas on 20/11/2023.
//

import SwiftUI

struct TappableView: View {
    var body: some View {
        Rectangle()
            .fill(.pink)
            .showTappableIndicators(lineWidth: 8)
    }

}

struct TappableIndicators: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // determine maximum arc size, based on rect's dimensions
        let maxSize = min(rect.width, rect.height) / 2

        let radius = maxSize/5

        // don't exceed maxSize
        let size = min(radius, maxSize)

        // Define the centers for each corner arc
        let centers = [
            CGPoint(x: rect.minX + size, y: rect.minY + size),
            CGPoint(x: rect.maxX - size, y: rect.minY + size),
            CGPoint(x: rect.maxX - size, y: rect.maxY - size),
            CGPoint(x: rect.minX + size, y: rect.maxY - size)
        ]

        // Define start and end angles for each corner
        let angles: [(CGFloat, CGFloat)] = [
            (CGFloat.pi, 1.5 * CGFloat.pi),
            (1.5 * CGFloat.pi, 2 * CGFloat.pi),
            (0, 0.5 * CGFloat.pi),
            (0.5 * CGFloat.pi, CGFloat.pi)
        ]

        // Create separate arcs for each corner
        for (index, center) in centers.enumerated() {
            let (startAngle, endAngle) = angles[index]
            path.move(to: CGPoint(x: center.x + size * cos(startAngle), y: center.y + size * sin(startAngle)))
            path.addArc(center: center, radius: size, startAngle: Angle(radians: startAngle), endAngle: Angle(radians: endAngle), clockwise: false)
        }

        return path
    }
}

struct ShowTappableIndicators: ViewModifier {
    var lineWidth: CGFloat = 10.0
    var lineCap: CGLineCap = .round
    var foregroundColor: Color = Color.primary

    func body(content: Content) -> some View {
        content
            .overlay {
                TappableIndicators()
                    .stroke(style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: lineCap
                    ))
                    .foregroundColor(foregroundColor)
                    .padding(lineWidth / 2)
            }
    }
}

extension View {
    func showTappableIndicators(
        lineWidth: CGFloat = 10.0,
        lineCap: CGLineCap = .round,
        foregroundColor: Color = Color.primary,
        padding: CGFloat = 0.0) -> some View {
        self.modifier(ShowTappableIndicators(lineWidth: lineWidth, lineCap: lineCap, foregroundColor: foregroundColor))
    }
}

#Preview {
    TappableView()
}
