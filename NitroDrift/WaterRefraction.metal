#include <metal_stdlib>
using namespace metal;
#include <SceneKit/scn_metal>

// Rendering supplied by SceneKit's DRAW_QUAD path.
struct NDWaterQuadIn {
    float4 position [[attribute(SCNVertexSemanticPosition)]];
};

struct NDWaterQuadOut {
    float4 position [[position]];
    float2 uv;
    float time;
};

vertex NDWaterQuadOut ndWaterQuad(
    NDWaterQuadIn input [[stage_in]],
    constant SCNSceneBuffer& frame [[buffer(0)]])
{
    NDWaterQuadOut output;
    output.position = input.position;
    output.uv = float2((input.position.x + 1.0) * 0.5,
                       (1.0 - input.position.y) * 0.5);
    output.time = frame.time;
    return output;
}

constexpr sampler ndScreenSampler(coord::normalized,
                                   address::clamp_to_edge,
                                   filter::linear);

fragment half4 ndWaterRefraction(
    NDWaterQuadOut in [[stage_in]],
    texture2d<float, access::sample> colorSampler [[texture(0)]],
    texture2d<float, access::sample> maskSampler [[texture(1)]])
{
    float2 uv = clamp(in.uv, float2(0.0), float2(1.0));
    float4 source = colorSampler.sample(ndScreenSampler, uv);
    float3 mask = maskSampler.sample(ndScreenSampler, uv).rgb;
    float coverage = smoothstep(0.08, 0.75, max(mask.r, max(mask.g, mask.b)));
    if (coverage < 0.001) return half4(source);

    float t = in.time;
    float2 p = uv * float2(37.0, 21.0);
    float sx = sin(p.x * 3.7 + t * 1.55) * cos(p.y * 2.45 - t * 0.8);
    float sy = cos(p.y * 4.2 - t * 1.2) * sin(p.x * 2.15 + t * 0.93);
    float ring = sin(length(p - float2(10.0, 6.0)) * 10.5 - t * 4.3);
    float3 n = normalize(float3(sx * 0.20 + ring * 0.06,
                                 sy * 0.20 - ring * 0.04, 1.0));

    // Water's index of refraction is ~1.333 in visible light. These rays
    // are evaluated at one screen-space interface; the sampled scene color
    // provides no true submerged geometry or thickness information.
    float3 incident = normalize(float3(0.10 + (uv.x - 0.5) * 0.18,
                                        0.22 + (uv.y - 0.5) * 0.16, -1.0));
    float3 transmitted = refract(incident, n, 1.0 / 1.333);
    float2 displacement = (transmitted.xy - incident.xy) * 0.038;
    float2 maxDisplacement = clamp(displacement, float2(-0.012), float2(0.012));
    float2 sampleUV = clamp(uv + maxDisplacement, float2(0.001), float2(0.999));

    // Mild wavelength dispersion, with the three channels sampled from the
    // actual rendered scene rather than synthesized from a tinted rectangle.
    float r = colorSampler.sample(ndScreenSampler, clamp(sampleUV * 1.003, 0.0, 1.0)).r;
    float g = colorSampler.sample(ndScreenSampler, sampleUV).g;
    float b = colorSampler.sample(ndScreenSampler, clamp(sampleUV * 0.997, 0.0, 1.0)).b;
    float3 refractedColor = float3(r, g, b);

    // Dielectric Fresnel / Schlick (R0 approximately 0.020).
    float ndv = saturate(dot(-incident, n));
    float fresnel = 0.020 + 0.980 * pow(1.0 - ndv, 5.0);
    float transmission = coverage * saturate(0.77 - fresnel * 0.62);
    float3 result = mix(source.rgb, refractedColor, transmission);
    return half4(float4(result, source.a));
}
