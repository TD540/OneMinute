//
//  DrumRoll.metal
//  OneMinute
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Wraps a flat view around an invisible drum lying on its side, its axis running horizontally
/// through the view's center. Content near the center faces the viewer; content further up or down
/// curves away, getting squashed and narrower, until it disappears over the drum's top or bottom
/// (if the drum is no taller than the view).
///
/// - Parameters:
///   - position: The point being drawn, in the view's coordinates.
///   - size: The view's size.
///   - radius: The drum's radius, in points.
///   - perspective: How much narrower content gets as it turns away: 0 for none.
/// - Returns: The point of the flat view to draw there.
[[ stitchable ]] float2 drumRoll(float2 position, float2 size, float radius, float perspective) {
    float2 center = size / 2;
    // Where on the drum this point is: the sine of its angle away from the viewer.
    float height = (position.y - center.y) / radius;
    if (abs(height) >= 1) {
        // Beyond the top or bottom of the drum: nothing to draw.
        return float2(-1, -1);
    }
    float angle = asin(height);
    // The flat view is wound onto the drum, so its distance from the center becomes arc length.
    float y = center.y + angle * radius;
    // Parts turned away are further from the viewer, so they look narrower.
    float depth = 1 - cos(angle);
    float x = center.x + (position.x - center.x) * (1 + perspective * depth);
    return float2(x, y);
}
