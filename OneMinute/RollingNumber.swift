//
//  RollingNumber.swift
//  OneMinute
//

import SwiftUI

/// A number that reads like a plain `Text`, except that each changing digit rolls vertically like
/// a mechanical drum counter: the old digit scrolls up and out while the new one rolls in from
/// below, clipped to the line height. Decreasing values roll the other way, carries cascade from
/// right to left, and unchanged digits stay still.
///
/// Font, color, line limit and scale factor come from the environment, as with `Text`.
struct RollingNumber: View {
    var value: Int
    /// How many digits to size the text for when it has to shrink to fit, so that shorter values
    /// are drawn at the same size as the longest one instead of growing.
    var reservedDigits = 1
    /// Space between digits as a fraction of a digit's width. Negative values pull the digits
    /// closer together than the font's own spacing, which is wide for equal-width digits.
    var tracking: CGFloat = -0.12
    /// How much of a digit's width, on the outer side of the first and last digit, may stick out
    /// of the frame: the empty space beside the digit, so the digits themselves reach its edges.
    var overhang: CGFloat = 0
    /// Delay in seconds between neighboring digits, so carries cascade from right to left.
    var stagger = 0.06

    /// Each digit's own width, and the size of an equal-width digit, at full font size.
    @State private var naturalWidths = Array(repeating: CGFloat(0), count: 10)
    @State private var equalWidth: CGFloat = 0

    var body: some View {
        let digitCount = String(value.magnitude).count
        // Each digit's own width as a fraction of the equal width; the same at any font size.
        let digitWidths = equalWidth > 0
            ? naturalWidths.map { $0 / equalWidth }
            : Array(repeating: 1, count: 10)
        DigitRow(reservedDigits: reservedDigits, tracking: tracking, overhang: overhang) {
            // Identified by place (ones, tens, …) so each drum keeps its state as the value changes.
            ForEach((0..<digitCount).reversed(), id: \.self) { place in
                // The outer digits lean inward, toward their neighbors.
                let lean: CGFloat = digitCount == 1 ? 0 : place == digitCount - 1 ? 1 : place == 0 ? -1 : 0
                DigitDrum(value: value, place: place, stagger: stagger, lean: lean, digitWidths: digitWidths)
            }
        }
        // Equal-width digits keep the drums from jiggling as they roll.
        .monospacedDigit()
        .background { measurements }
        .animation(.smooth, value: digitCount)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(value))
    }

    /// Measures the digits in the current font, at full size.
    private var measurements: some View {
        ZStack {
            Text("0")
                .monospacedDigit()
                .fixedSize()
                .onGeometryChange(for: CGFloat.self, of: \.size.width) { equalWidth = $0 }
            ForEach(0..<10, id: \.self) { digit in
                Text(String(digit))
                    .fixedSize()
                    .onGeometryChange(for: CGFloat.self, of: \.size.width) { naturalWidths[digit] = $0 }
            }
        }
        .hidden()
    }
}

/// Lays out digits side by side, offering each the width of one of `reservedDigits` columns,
/// so every digit shrinks (through `minimumScaleFactor`) by the same amount whatever their count.
/// Digits are `tracking` digit widths apart, overlapping their frames when it's negative, and the
/// first and last stick out of the row by `overhang` digit widths.
private struct DigitRow: Layout {
    var reservedDigits: Int
    var tracking: CGFloat
    var overhang: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(columnProposal(proposal, count: subviews.count)) }
        let widths = sizes.reduce(0) { $0 + $1.width }
        let gaps = sizes.dropLast().reduce(0) { $0 + $1.width * tracking }
        let overhangs = ((sizes.first?.width ?? 0) + (sizes.last?.width ?? 0)) * overhang
        return CGSize(width: max(widths + gaps - overhangs, 0), height: sizes.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let column = columnProposal(proposal, count: subviews.count)
        var x = bounds.minX - (subviews.first?.sizeThatFits(column).width ?? 0) * overhang
        for subview in subviews {
            subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading, proposal: column)
            x += subview.sizeThatFits(column).width * (1 + tracking)
        }
    }

    /// The width that lets `reservedDigits` digits, with the gaps between them and less the
    /// overhangs, fill the proposal.
    private func columnProposal(_ proposal: ProposedViewSize, count: Int) -> ProposedViewSize {
        let columns = CGFloat(max(reservedDigits, count))
        let width = proposal.width.map { $0 / (columns + (columns - 1) * tracking - 2 * overhang) }
        return ProposedViewSize(width: width, height: proposal.height)
    }
}

/// One digit of a `RollingNumber`: a drum that rolls one step whenever its digit changes.
private struct DigitDrum: View {
    var value: Int
    /// 0 for the ones, 1 for the tens, and so on.
    var place: Int
    var stagger: Double
    var lean: CGFloat
    var digitWidths: [CGFloat]

    /// The drum's position, one step per roll: up when the value increases, down when it decreases.
    @State private var position = 0
    /// The digit printed at each position of the drum; positions without one are blank.
    @State private var faces: [Int: Int]

    init(value: Int, place: Int, stagger: Double, lean: CGFloat, digitWidths: [CGFloat]) {
        self.value = value
        self.place = place
        self.stagger = stagger
        self.lean = lean
        self.digitWidths = digitWidths
        // Digits that appear later, like the tens at 10, roll in from a blank face.
        _faces = State(initialValue: place == 0 ? [0: Self.digit(of: value, at: place)] : [:])
    }

    var body: some View {
        DrumFaces(position: Double(position), faces: faces, lean: lean, digitWidths: digitWidths)
            .onAppear {
                if faces.isEmpty { roll(to: Self.digit(of: value, at: place), up: true) }
            }
            .onChange(of: value) { old, new in
                let digit = Self.digit(of: new, at: place)
                guard digit != Self.digit(of: old, at: place) else { return }
                roll(to: digit, up: new > old)
            }
    }

    private func roll(to digit: Int, up: Bool) {
        let next = position + (up ? 1 : -1)
        // The new face is printed right away; it stays out of sight until the drum turns.
        faces[next] = digit
        // Keep the faces a roll that's still catching up may pass, drop the rest.
        faces = faces.filter { abs($0.key - next) <= 10 }
        withAnimation(.spring(duration: 0.4, bounce: 0.15).delay(Double(place) * stagger)) {
            position = next
        }
    }

    private static func digit(of value: Int, at place: Int) -> Int {
        Int(value.magnitude / (0..<place).reduce(1) { power, _ in power * 10 } % 10)
    }
}

/// Draws the faces around a drum position, printed one below the other on a strip wound around an
/// invisible drum, which shows through the line like an odometer's window. The face in front reads
/// like plain text; at a fractional position the faces travel together over the drum's curve,
/// getting squashed and narrower toward the top and bottom of the line.
///
/// Faces are printed off-center, toward the side the drum leans to, by however much narrower
/// their digit is than the drum: so a 1 sits as close to its neighbor as it would in plain text.
@Animatable
private struct DrumFaces: View {
    var position: Double
    @AnimatableIgnored var faces: [Int: Int]
    /// -1 to lean left, 1 to lean right, 0 to stay centered.
    @AnimatableIgnored var lean: CGFloat = 0
    /// Each digit's own width as a fraction of the equal width the drum is as wide as.
    @AnimatableIgnored var digitWidths: [CGFloat] = Array(repeating: 1, count: 10)

    /// The drum's radius, in line heights; at least 0.5, the line being the drum's window. Smaller
    /// drums curve more.
    private let radius = 0.6
    /// How much narrower faces get as they turn away.
    private let perspective = 0.4

    var body: some View {
        let base = position.rounded(.down)
        let fraction = position - base
        let radius = radius, perspective = perspective

        ZStack {
            face(at: Int(base))
                .visualEffect { content, proxy in
                    content.offset(y: -fraction * proxy.size.height)
                }
            face(at: Int(base) + 1)
                .visualEffect { content, proxy in
                    content.offset(y: (1 - fraction) * proxy.size.height)
                }
        }
        .visualEffect { content, proxy in
            let radius = radius * proxy.size.height
            // How far up or down the drum moves content at most: at the window's top and bottom.
            let edge = proxy.size.height / 2
            return content.distortionEffect(
                ShaderLibrary.drumRoll(.float2(proxy.size), .float(radius), .float(perspective)),
                maxSampleOffset: CGSize(
                    width: proxy.size.width / 2 * perspective,
                    height: radius * asin(edge / radius) - edge
                )
            )
        }
        .clipped()
    }

    /// A blank face still takes up a digit's size, so the width doesn't change.
    private func face(at position: Int) -> some View {
        let digit = faces[position]
        let shift = digit.map { lean * (1 - digitWidths[$0]) / 2 } ?? 0
        return Text(String(digit ?? 0))
            .opacity(digit == nil ? 0 : 1)
            .visualEffect { content, proxy in
                content.offset(x: shift * proxy.size.width)
            }
    }
}

#Preview("Mid-roll") {
    HStack {
        ForEach([0, 0.25, 0.5, 0.75], id: \.self) { position in
            DrumFaces(position: position, faces: [0: 1, 1: 2])
                .border(.red)
        }
    }
    .font(.system(size: 120, weight: .black, design: .rounded))
}

#Preview {
    @Previewable @State var value = 7

    VStack(spacing: 40) {
        // Sized like the app: too big to fit, so it shrinks, the same for one digit as for two.
        RollingNumber(value: value, reservedDigits: 2)
            .font(.system(size: 400, weight: .black, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .padding(40)
        HStack {
            Button("−1") { value -= 1 }
            Button("+1") { value += 1 }
            Button("+13") { value += 13 }
        }
        .buttonStyle(.bordered)
    }
}
