import Foundation
import Metal
import SceneKit

/// A 126 m segment has a unique color map and a tangent-normal/roughness map.
/// Read and upload just the nearby segments. Physics and navigation use the grid.
final class RoadSurfaceStream {
    private struct Segment: Hashable {
        let eastWest: Bool
        let road: Int
        let span: Int
        var name: String { "\(eastWest ? "ew" : "ns")-\(road)-\(span)" }
        var lane: Double { Double(road * 150 - 450) }
        var mid: Double { Double(span * 150 - 375) }

        func squaredDistance(x: Double, z: Double) -> Double {
            let across = max(0, abs((eastWest ? z : x) - lane) - 12)
            let along = max(0, abs((eastWest ? x : z) - mid) - 63)
            return across * across + along * along
        }
    }

    private struct Key: Hashable { let segment: Segment; let firstMip: Int }
    private struct Maps { let color: MTLTexture; let surface: MTLTexture }
    private let root = SCNNode()
    private let queue = DispatchQueue(label: "NitroDrift.road-textures", qos: .userInitiated)
    private let device = MTLCreateSystemDefaultDevice()
    private let folder = Bundle.main.resourceURL?.appendingPathComponent("RoadPack", isDirectory: true)
    private let segments: [Segment]
    private var wanted: [Key] = []
    private var resident: [Key: (SCNNode, Maps)] = [:]
    private var missing = Set<Key>()
    private var loading = false
    private var wet = false
    private var lastX = -10_000.0, lastZ = -10_000.0
    private var lastQuality: GraphicsQuality?
    var available: Bool { !segments.isEmpty }
    private(set) var activeCount = 0

    init(scene: SCNScene) {
        var list = [Segment]()
        for eastWest in [false, true] {
            for road in 0..<7 {
                for span in 0..<6 { list.append(Segment(eastWest: eastWest, road: road, span: span)) }
            }
        }
        if let device, device.supportsFamily(.apple2), let folder,
           FileManager.default.fileExists(atPath: folder.appendingPathComponent("ns-3-3.ndroad").path) {
            segments = list
        } else {
            segments = []
        }
        root.name = "streamed-road-surfaces"
        scene.rootNode.addChildNode(root)
    }

    func update(x: Double, z: Double, quality: GraphicsQuality, raining: Bool) {
        guard !segments.isEmpty else { return }
        if wet != raining {
            wet = raining
            for (node, maps) in resident.values {
                if let mat = node.geometry?.firstMaterial { configure(mat, maps: maps) }
            }
        }
        guard lastQuality != quality || abs(x - lastX) + abs(z - lastZ) >= 7 else { return }
        lastQuality = quality
        lastX = x
        lastZ = z
        let firstMip = quality == .balanced ? 1 : 0
        let limit = quality == .ultra ? 7 : quality == .cinematic ? 5 : 3
        wanted = segments.map { ($0, $0.squaredDistance(x: x, z: z)) }
            .filter { $0.1 < 150 * 150 }
            .sorted { $0.1 < $1.1 }.prefix(limit).map { Key(segment: $0.0, firstMip: firstMip) }
        for key in Array(resident.keys) where !wanted.contains(key) {
            resident.removeValue(forKey: key)?.0.removeFromParentNode()
        }
        activeCount = resident.count
        loadNext()
    }

    private func loadNext() {
        guard !loading, let device, let folder,
              let key = wanted.first(where: { resident[$0] == nil && !missing.contains($0) }) else { return }
        loading = true
        let url = folder.appendingPathComponent(key.segment.name + ".ndroad")
        queue.async { [weak self] in
            let maps = autoreleasepool { Self.read(url, device: device, firstMip: key.firstMip) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.loading = false
                if let maps {
                    if self.wanted.contains(key) { self.install(maps, key: key) }
                } else { self.missing.insert(key) }
                self.loadNext()
            }
        }
    }

    private func install(_ maps: Maps, key: Key) {
        let segment = key.segment
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = maps.color
        mat.normal.contents = maps.surface
        mat.metalness.contents = 0.025
        for prop in [mat.diffuse, mat.normal, mat.roughness] {
            prop.mipFilter = .linear
            prop.minificationFilter = .linear
            prop.maxAnisotropy = 8
        }
        configure(mat, maps: maps)
        let plane = SCNPlane(width: 24, height: 126)
        plane.firstMaterial = mat
        let node = SCNNode(geometry: plane)
        node.name = segment.name
        node.eulerAngles = SCNVector3(-Float.pi / 2, segment.eastWest ? Float.pi / 2 : 0, 0)
        node.position = SCNVector3(Float(segment.eastWest ? segment.mid : segment.lane),
                                   0.092, Float(segment.eastWest ? segment.lane : segment.mid))
        node.castsShadow = false
        root.addChildNode(node)
        resident[key] = (node, maps)
        activeCount = resident.count
    }

    private func configure(_ mat: SCNMaterial, maps: Maps) {
        mat.normal.intensity = wet ? 0.34 : 0.65
        if wet {
            mat.roughness.textureComponents = .all
            mat.roughness.contents = 0.19
        } else {
            mat.roughness.contents = maps.surface
            mat.roughness.textureComponents = .alpha
        }
    }

    private static func read(_ url: URL, device: MTLDevice, firstMip: Int) -> Maps? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe), data.count >= 20 else { return nil }
        return data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Maps? in
            guard let base = raw.baseAddress else { return nil }
            func word(_ offset: Int) -> UInt32 {
                UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
            }
            guard word(0) == 0x3152444e, word(4) == 1, word(8) == 1024,
                  word(12) == 5120, word(16) == 13 else { return nil }
            func texture(_ format: MTLPixelFormat) -> MTLTexture? {
                let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format,
                    width: 1024 >> firstMip, height: 5120 >> firstMip, mipmapped: true)
                desc.usage = .shaderRead
                desc.storageMode = .shared
                return device.makeTexture(descriptor: desc)
            }
            guard let color = texture(.astc_4x4_srgb), let surface = texture(.astc_4x4_ldr) else { return nil }
            var offset = 20
            for mip in 0..<13 {
                let w = max(1, 1024 >> mip), h = max(1, 5120 >> mip)
                let row = ((w + 3) / 4) * 16, length = row * ((h + 3) / 4)
                guard offset + 2 * length <= raw.count else { return nil }
                if mip >= firstMip {
                    let region = MTLRegionMake2D(0, 0, w, h)
                    color.replace(region: region, mipmapLevel: mip - firstMip,
                                  withBytes: base.advanced(by: offset), bytesPerRow: row)
                    surface.replace(region: region, mipmapLevel: mip - firstMip,
                                    withBytes: base.advanced(by: offset + length), bytesPerRow: row)
                }
                offset += 2 * length
            }
            return offset == raw.count ? Maps(color: color, surface: surface) : nil
        }
    }
}
