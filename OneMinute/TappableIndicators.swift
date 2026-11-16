//
//  TappableIndicators.swift
//  OneMinute
//

import SwiftUI

extension View {
    /// Draws corner brackets that follow the display's rounded corners, hinting that the whole
    /// area can be tapped. The lines run through the center of the camera (Dynamic Island or
    /// camera hole), and the corner holding the camera (like on iPhone Duo) gets no bracket.
    func tappableIndicators(color: Color = .primary, lineWidth: CGFloat = 8) -> some View {
        overlay {
            GeometryReader { proxy in
                let bounds = CGRect(origin: .zero, size: proxy.size)
                let camera = proxy.camera
                let inset = proxy.tappableIndicatorsInset
                let rect = bounds.insetBy(dx: inset, dy: inset)

                CornerBrackets(
                    rect: rect,
                    radii: proxy.concentricCornerRadii(in: rect) ?? RectangleCornerRadii(),
                    camera: camera
                )
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
        }
    }
}

extension GeometryProxy {
    /// The camera (Dynamic Island or camera hole), in this proxy's coordinates. It's the smallest
    /// reserved region; others, like the Duo's side controls, are larger. Regions are only reported
    /// in the running app, not in previews.
    fileprivate var camera: CGRect? {
        reservedRegions(kind: .occlusion, layoutDirectionBehavior: .fixed)
            .map { region in
                // The hardware itself, without the margins the system adds around it.
                let frame = region.frame, margins = region.margins
                return CGRect(
                    x: frame.minX + margins.leading,
                    y: frame.minY + margins.top,
                    width: frame.width - margins.leading - margins.trailing,
                    height: frame.height - margins.top - margins.bottom
                )
            }
            .min { $0.width * $0.height < $1.width * $1.height }
    }

    /// Distance from the edges to the lines of `tappableIndicators`, for a proxy covering the
    /// display: that of the camera's center, so the lines line up with it. The same on all sides,
    /// and 20 pt on displays without a camera.
    var tappableIndicatorsInset: CGFloat {
        let bounds = CGRect(origin: .zero, size: size)
        return camera.map { min($0.midX, bounds.maxX - $0.midX, $0.midY, bounds.maxY - $0.midY) } ?? 20
    }
}

/// An L-shaped line in each corner of `rect`, bent like the system's continuous rounded corners,
/// except in the corner holding the camera.
private struct CornerBrackets: Shape {
    var rect: CGRect
    var radii: RectangleCornerRadii
    var camera: CGRect?

    func path(in bounds: CGRect) -> Path {
        let arm = min(rect.width, rect.height) / 5
        var brackets = Path()

        for bend in bends() {
            let corner = bend.corner
            if let camera, hypot(camera.midX - corner.x, camera.midY - corner.y) < arm { continue }

            // The ends of the two arms, pointing from the corner toward the middle.
            let dx: CGFloat = corner.x == rect.minX ? 1 : -1
            let dy: CGFloat = corner.y == rect.minY ? 1 : -1
            let horizontalEnd = CGPoint(x: corner.x + dx * arm, y: corner.y)
            let verticalEnd = CGPoint(x: corner.x, y: corner.y + dy * arm)

            // Arm, bend, arm, as one line. The bend starts on one edge and ends on the other.
            let startsHorizontally = abs(bend.start.y - corner.y) < 0.01
            brackets.move(to: startsHorizontally ? horizontalEnd : verticalEnd)
            brackets.addLine(to: bend.start)
            for curve in bend.curves {
                brackets.addCurve(to: curve.to, control1: curve.control1, control2: curve.control2)
            }
            brackets.addLine(to: startsHorizontally ? verticalEnd : horizontalEnd)
        }
        return brackets
    }

    private typealias Curve = (to: CGPoint, control1: CGPoint, control2: CGPoint)

    /// The corner curves of the system's continuous rounded rectangle, taken from its path.
    private func bends() -> [(corner: CGPoint, start: CGPoint, curves: [Curve])] {
        // Square corners (like the Duo's hinge side) get a 1 pt radius so every corner has a bend;
        // it's invisible under the round line caps.
        let radii = RectangleCornerRadii(
            topLeading: max(radii.topLeading, 1),
            bottomLeading: max(radii.bottomLeading, 1),
            bottomTrailing: max(radii.bottomTrailing, 1),
            topTrailing: max(radii.topTrailing, 1)
        )
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)
        ]

        var bends: [(corner: CGPoint, start: CGPoint, curves: [Curve])] = []
        var last = CGPoint.zero
        var lastWasCurve = false
        Path(roundedRect: rect, cornerRadii: radii, style: .continuous).forEach { element in
            switch element {
            case .curve(let to, let control1, let control2):
                if !lastWasCurve {
                    let corner = corners.min { hypot($0.x - last.x, $0.y - last.y) < hypot($1.x - last.x, $1.y - last.y) }!
                    bends.append((corner, last, []))
                }
                bends[bends.count - 1].curves.append((to, control1, control2))
                last = to
                lastWasCurve = true
            case .move(let point), .line(let point):
                last = point
                lastWasCurve = false
            default:
                lastWasCurve = false
            }
        }
        return bends
    }
}

#Preview {
    Color.pink
        .tappableIndicators()
        .ignoresSafeArea()
}
