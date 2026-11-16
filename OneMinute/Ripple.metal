//
//  Ripple.metal
//  OneMinute
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// A ring of waves spreading out from a point, like a drop falling into water. Each point starts
/// to wave once the ring reaches it, then settles down. Wave crests are lightened a little.
///
/// - Parameters:
///   - position: The point being drawn, in the view's coordinates.
///   - layer: The view being rippled.
///   - origin: Where the drop fell, in the view's coordinates.
///   - time: Seconds since the drop fell.
///   - amplitude: How far the waves push content, in points.
///   - frequency: How fast each point waves back and forth.
///   - decay: How fast the waves settle down.
///   - speed: How fast the ring spreads, in points per second.
[[ stitchable ]] half4 ripple(
    float2 position,
    SwiftUI::Layer layer,
    float2 origin,
    float time,
    float amplitude,
    float frequency,
    float decay,
    float speed
) {
    float distance = length(position - origin);
    // Time since the ring reached this point.
    float local = max(0.0, time - distance / speed);
    float wave = amplitude * sin(frequency * local) * exp(-decay * local);

    // Push content along the line from the origin, and lighten the crests.
    float2 direction = distance > 0 ? (position - origin) / distance : float2(0);
    half4 color = layer.sample(position + wave * direction);
    color.rgb += 0.3 * (wave / amplitude) * color.a;
    return color;
}
