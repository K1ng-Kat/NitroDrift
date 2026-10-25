import SceneKit
import Foundation

/// Ultra-only, two-scene-pass screen-space refraction.
///
/// Pass 1 renders the normal scene into an offscreen color texture excluding
/// hidden water mask proxies. Pass 2 renders only the mask proxies; the Metal
/// compositor uses Snell's law to perturb lookups into the offscreen scene.
/// This is screen-space transmission, NOT an intersection-tested ray tracer.
/// Pixels hidden from the camera cannot be recovered from one color buffer.
enum ScreenSpaceWater {
    static let waterMaskCategory = 4

    static func makeTechnique() -> SCNTechnique? {
        let scenePass: [String: Any] = [
            "draw": "DRAW_SCENE",
            "excludeCategoryMask": waterMaskCategory,
            "outputs": ["color": "sceneColor"],
            "colorStates": [
                "clear": true,
                "clearColor": "sceneBackground"
            ]
        ]
        let maskPass: [String: Any] = [
            "draw": "DRAW_SCENE",
            "includeCategoryMask": waterMaskCategory,
            "outputs": ["color": "waterMask"],
            "colorStates": [
                "clear": true,
                "clearColor": "0 0 0 0"
            ]
        ]
        let composite: [String: Any] = [
            "draw": "DRAW_QUAD",
            // SceneKit expects a program entry even with Metal functions.
            "program": "water_composite",
            "metalVertexShader": "ndWaterQuad",
            "metalFragmentShader": "ndWaterRefraction",
            "inputs": [
                "colorSampler": "sceneColor",
                "maskSampler": "waterMask"
            ],
            "outputs": ["color": "COLOR"]
        ]
        return SCNTechnique(dictionary: [
            "passes": [
                "scene": scenePass,
                "mask": maskPass,
                "composite": composite
            ],
            "sequence": ["scene", "mask", "composite"],
            "targets": [
                "sceneColor": ["type": "color"],
                "waterMask": ["type": "color"]
            ]
        ])
    }
}
