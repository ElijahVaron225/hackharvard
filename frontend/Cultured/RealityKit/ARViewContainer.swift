// ARViewContainer.swift
import SwiftUI
import RealityKit
import Combine
import QuartzCore
import UIKit
import CoreMotion

// MARK: - Heirloom "card" builders (portable/compile-safe)

/// Thin translucent box (glass plaque look)
func makeTranslucentBox(
    size: SIMD3<Float> = SIMD3<Float>(0.28, 0.20, 0.035),
    alpha: Float = 0.28
) -> ModelEntity {
    let mesh = MeshResource.generateBox(size: size)

    var glass = SimpleMaterial()
    glass.color = .init(tint: UIColor.white.withAlphaComponent(CGFloat(alpha)), texture: nil)
    glass.metallic = 0.0
    glass.roughness = 0.18

    return ModelEntity(mesh: mesh, materials: [glass])
}

/// Rounded translucent box with curved corners for billboard-style card
func makeRoundedTranslucentBox(
    size: SIMD3<Float> = SIMD3<Float>(0.32, 0.24, 0.04),
    alpha: Float = 0.25,
    cornerRadius: Float = 0.08
) -> ModelEntity {
    // Create a rounded box mesh
    let mesh = MeshResource.generateBox(
        size: size,
        cornerRadius: cornerRadius
    )

    var glass = PhysicallyBasedMaterial()
    glass.baseColor = .init(tint: UIColor.white.withAlphaComponent(CGFloat(alpha)), texture: nil)
    glass.metallic = 0.0
    glass.roughness = 0.15
    glass.faceCulling = .none
    glass.blending = .transparent(opacity: .init(scale: alpha))

    return ModelEntity(mesh: mesh, materials: [glass])
}

/// Billboard plane that always faces camera; maps PNG (alpha respected)
func makeCutoutBillboard(
    image: UIImage,
    targetWidth: Float = 0.24
) async throws -> ModelEntity {
    guard let cg = image.cgImage else {
        throw NSError(domain: "Heirloom", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "PNG missing CGImage"])
    }

    // Texture creation (iOS 18 API with fallback)
    let tex: TextureResource
    if #available(iOS 18.0, *) {
        tex = try await TextureResource(
            image: cg,
            withName: "cutout_\(UUID().uuidString)",
            options: .init(semantic: .color)
        )
    } else {
        tex = try TextureResource.generate(
            from: cg,
            options: .init(semantic: .color)
        )
    }

    // Plane sized by image aspect
    let aspect = Float(image.size.width / image.size.height)
    let mesh  = MeshResource.generatePlane(width: targetWidth, height: targetWidth / aspect)

    // Material: PBR with baseColor texture (stable across RealityKit versions)
    var pbr = PhysicallyBasedMaterial()
    pbr.baseColor = .init(
        tint: UIColor.white,
        texture: .init(tex)
    )
    pbr.faceCulling = .none
    pbr.blending = .transparent(opacity: .init(scale: 1.0, texture: .init(tex)))

    let entity = ModelEntity(mesh: mesh, materials: [pbr])
    entity.components[BillboardComponent.self] = BillboardComponent() // always face camera
    return entity
}

/// Assembles the translucent box + pinned cutout (offset to avoid z-fighting)
func makeHeirloomCard(image: UIImage) async throws -> Entity {
    let box = makeTranslucentBox()
    let cutout = try await makeCutoutBillboard(image: image, targetWidth: 0.24)

    // Push the plane slightly off the box front (half depth ≈ 0.0175 + a hair)
    cutout.position = SIMD3<Float>(0.0, 0.0, 0.019)

    // Optional: soft shadow "mat" below
    let shadowPlane = ModelEntity(mesh: .generatePlane(width: 0.18, height: 0.12))
    var shadowMat = UnlitMaterial()
    shadowMat.baseColor = .color(UIColor.black.withAlphaComponent(0.14))
    shadowPlane.model?.materials = [shadowMat]
    shadowPlane.orientation = simd_quatf(angle: -.pi/2, axis: SIMD3<Float>(1, 0, 0))
    shadowPlane.position = SIMD3<Float>(0.0, -(0.20/2.0 + 0.005), 0.0)

    let group = Entity()
    group.addChild(box)
    group.addChild(cutout)
    group.addChild(shadowPlane)
    return group
}

/// Creates a curved plaque with image projected onto its surface
func makeBillboardCard(image: UIImage) async throws -> Entity {
    // Calculate image aspect ratio to scale the plaque appropriately
    let imageAspect = Float(image.size.width / image.size.height)
    let baseWidth: Float = 0.28
    let baseHeight = baseWidth / imageAspect
    
    // Scale the plaque to fit the image dimensions
    let plaqueSize = SIMD3<Float>(baseWidth, baseHeight, 0.04)
    let cornerRadius = min(baseWidth, baseHeight) * 0.25 // Proportional corner radius
    
    // Create the interactive button-style plaque
    let interactiveButton = try await makeInteractiveButtonPlaque(
        image: image,
        size: plaqueSize,
        cornerRadius: cornerRadius
    )
    
    // Add a subtle border frame
    let borderFrame = makeRoundedTranslucentBox(
        size: SIMD3<Float>(baseWidth + 0.06, baseHeight + 0.06, 0.01),
        alpha: 0.15,
        cornerRadius: cornerRadius + 0.01
    )
    borderFrame.position = SIMD3<Float>(0.0, 0.0, 0.005)
    
    // Add a soft shadow below
    let shadowPlane = ModelEntity(mesh: .generatePlane(width: baseWidth + 0.04, height: baseHeight + 0.04))
    var shadowMat = UnlitMaterial()
    shadowMat.baseColor = .color(UIColor.black.withAlphaComponent(0.12))
    shadowPlane.model?.materials = [shadowMat]
    shadowPlane.orientation = simd_quatf(angle: -.pi/2, axis: SIMD3<Float>(1, 0, 0))
    shadowPlane.position = SIMD3<Float>(0.0, -(baseHeight/2.0 + 0.008), 0.0)
    
    let group = Entity()
    group.addChild(interactiveButton)
    group.addChild(borderFrame)
    group.addChild(shadowPlane)
    
    return group
}

/// Preprocesses image to ensure clean transparent background
func preprocessImageForTransparency(_ image: UIImage) -> UIImage? {
    guard let cgImage = image.cgImage else { return nil }
    
    let width = cgImage.width
    let height = cgImage.height
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let bitsPerComponent = 8
    
    var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
    
    guard let context = CGContext(
        data: &pixelData,
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    
    // Process pixels to clean up semi-transparent background
    for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
        let alpha = pixelData[i + 3] // Alpha channel
        
        // If alpha is very low (semi-transparent), make it fully transparent
        if alpha < 30 {
            pixelData[i + 3] = 0 // Set alpha to 0 (fully transparent)
        }
        // If alpha is high enough, make it fully opaque
        else if alpha > 50 {
            pixelData[i + 3] = 255 // Set alpha to 255 (fully opaque)
        }
    }
    
    guard let processedCGImage = context.makeImage() else { return nil }
    return UIImage(cgImage: processedCGImage)
}

/// Creates a curved plaque with image texture projected onto its surface
func makeCurvedPlaqueWithImage(
    image: UIImage,
    size: SIMD3<Float>,
    cornerRadius: Float
) async throws -> ModelEntity {
    guard let cg = image.cgImage else {
        throw NSError(domain: "Heirloom", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "PNG missing CGImage"])
    }

    // Create texture from original image (no preprocessing)
    let tex: TextureResource
    if #available(iOS 18.0, *) {
        tex = try await TextureResource(
            image: cg,
            withName: "plaque_\(UUID().uuidString)",
            options: .init(semantic: .color)
        )
    } else {
        tex = try TextureResource.generate(
            from: cg,
            options: .init(semantic: .color)
        )
    }

    // Create rounded box mesh
    let mesh = MeshResource.generateBox(
        size: size,
        cornerRadius: cornerRadius
    )

    // Create material with image texture projected onto the curved surface
    var plaqueMaterial = PhysicallyBasedMaterial()
    plaqueMaterial.baseColor = .init(
        tint: UIColor.white,
        texture: .init(tex)
    )
    plaqueMaterial.metallic = 0.0
    plaqueMaterial.roughness = 0.1
    plaqueMaterial.faceCulling = .none
    // Use opaque blending for solid images (JPG) or transparent for PNG with alpha
    plaqueMaterial.blending = .opaque

    return ModelEntity(mesh: mesh, materials: [plaqueMaterial])
}

/// Creates a modern interactive button-style plaque with gradient and shadow effects
func makeInteractiveButtonPlaque(
    image: UIImage,
    size: SIMD3<Float>,
    cornerRadius: Float
) async throws -> Entity {
    guard let cg = image.cgImage else {
        throw NSError(domain: "Heirloom", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "PNG missing CGImage"])
    }

    // Create texture from image
    let tex: TextureResource
    if #available(iOS 18.0, *) {
        tex = try await TextureResource(
            image: cg,
            withName: "button_\(UUID().uuidString)",
            options: .init(semantic: .color)
        )
    } else {
        tex = try TextureResource.generate(
            from: cg,
            options: .init(semantic: .color)
        )
    }

    // Create the main button surface with gradient effect
    let buttonMesh = MeshResource.generateBox(
        size: size,
        cornerRadius: cornerRadius
    )

    // Create a subtle gradient material for the button
    var buttonMaterial = PhysicallyBasedMaterial()
    buttonMaterial.baseColor = .init(
        tint: UIColor.white,
        texture: .init(tex)
    )
    buttonMaterial.metallic = 0.1
    buttonMaterial.roughness = 0.2
    buttonMaterial.faceCulling = .none
    buttonMaterial.blending = .opaque

    let buttonEntity = ModelEntity(mesh: buttonMesh, materials: [buttonMaterial])

    // Add a subtle inner shadow/depth effect
    let innerShadowMesh = MeshResource.generateBox(
        size: SIMD3<Float>(size.x * 0.95, size.y * 0.95, size.z * 0.5),
        cornerRadius: cornerRadius * 0.9
    )
    
    var shadowMaterial = PhysicallyBasedMaterial()
    shadowMaterial.baseColor = .init(tint: UIColor.black.withAlphaComponent(0.1))
    shadowMaterial.metallic = 0.0
    shadowMaterial.roughness = 0.8
    shadowMaterial.faceCulling = .none
    shadowMaterial.blending = .transparent(opacity: .init(scale: 0.1))
    
    let innerShadow = ModelEntity(mesh: innerShadowMesh, materials: [shadowMaterial])
    innerShadow.position = SIMD3<Float>(0.0, 0.0, -0.01)

    // Add a subtle highlight/gloss effect
    let highlightMesh = MeshResource.generateBox(
        size: SIMD3<Float>(size.x * 0.8, size.y * 0.3, size.z * 0.02),
        cornerRadius: cornerRadius * 0.8
    )
    
    var highlightMaterial = PhysicallyBasedMaterial()
    highlightMaterial.baseColor = .init(tint: UIColor.white.withAlphaComponent(0.3))
    highlightMaterial.metallic = 0.8
    highlightMaterial.roughness = 0.1
    highlightMaterial.faceCulling = .none
    highlightMaterial.blending = .transparent(opacity: .init(scale: 0.3))
    
    let highlight = ModelEntity(mesh: highlightMesh, materials: [highlightMaterial])
    highlight.position = SIMD3<Float>(0.0, size.y * 0.25, size.z * 0.49)

    // Create audio icon in bottom right corner
    let audioIconSize: Float = min(size.x, size.y) * 0.15
    let audioIconMesh = MeshResource.generateBox(
        size: SIMD3<Float>(audioIconSize, audioIconSize * 0.6, size.z * 0.02),
        cornerRadius: audioIconSize * 0.1
    )
    
    var audioIconMaterial = PhysicallyBasedMaterial()
    audioIconMaterial.baseColor = .init(tint: UIColor.systemBlue)
    audioIconMaterial.metallic = 0.3
    audioIconMaterial.roughness = 0.2
    audioIconMaterial.faceCulling = .none
    audioIconMaterial.blending = .opaque
    
    let audioIcon = ModelEntity(mesh: audioIconMesh, materials: [audioIconMaterial])
    audioIcon.position = SIMD3<Float>(
        size.x * 0.35,  // Right side
        -size.y * 0.35, // Bottom
        size.z * 0.51   // Slightly in front
    )

    // Create the complete button group
    let buttonGroup = Entity()
    buttonGroup.addChild(buttonEntity)
    buttonGroup.addChild(innerShadow)
    buttonGroup.addChild(highlight)
    buttonGroup.addChild(audioIcon)

    // Add a subtle pulsing animation to indicate interactivity
    let pulseAnimation = FromToByAnimation<Transform>(
        name: "pulse",
        from: Transform(scale: SIMD3<Float>(1.0, 1.0, 1.0)),
        to: Transform(scale: SIMD3<Float>(1.02, 1.02, 1.02)),
        duration: 2.0,
        timing: .easeInOut,
        repeatMode: .repeat
    )
    
    let animationResource = try AnimationResource.generate(with: pulseAnimation)
    buttonGroup.playAnimation(animationResource)

    return buttonGroup
}

/// Alternative approach: Creates a plaque with a solid background and image overlay
func makeBillboardCardWithSolidBackground(image: UIImage) async throws -> Entity {
    // Calculate image aspect ratio to scale the plaque appropriately
    let imageAspect = Float(image.size.width / image.size.height)
    let baseWidth: Float = 0.28
    let baseHeight = baseWidth / imageAspect
    
    // Scale the plaque to fit the image dimensions
    let plaqueSize = SIMD3<Float>(baseWidth, baseHeight, 0.04)
    let cornerRadius = min(baseWidth, baseHeight) * 0.25 // Proportional corner radius
    
    // Create solid white background
    let solidBackground = makeRoundedTranslucentBox(
        size: plaqueSize,
        alpha: 1.0, // Fully opaque white background
        cornerRadius: cornerRadius
    )
    
    // Create image as a separate plane on top
    let imagePlane = try await makeCutoutBillboard(image: image, targetWidth: baseWidth * 0.9)
    imagePlane.position = SIMD3<Float>(0.0, 0.0, 0.021) // Slightly in front
    
    // Add border frame
    let borderFrame = makeRoundedTranslucentBox(
        size: SIMD3<Float>(baseWidth + 0.06, baseHeight + 0.06, 0.01),
        alpha: 0.15,
        cornerRadius: cornerRadius + 0.01
    )
    borderFrame.position = SIMD3<Float>(0.0, 0.0, 0.005)
    
    // Add shadow
    let shadowPlane = ModelEntity(mesh: .generatePlane(width: baseWidth + 0.04, height: baseHeight + 0.04))
    var shadowMat = UnlitMaterial()
    shadowMat.baseColor = .color(UIColor.black.withAlphaComponent(0.12))
    shadowPlane.model?.materials = [shadowMat]
    shadowPlane.orientation = simd_quatf(angle: -.pi/2, axis: SIMD3<Float>(1, 0, 0))
    shadowPlane.position = SIMD3<Float>(0.0, -(baseHeight/2.0 + 0.008), 0.0)
    
    let group = Entity()
    group.addChild(solidBackground)
    group.addChild(imagePlane)
    group.addChild(borderFrame)
    group.addChild(shadowPlane)
    
    return group
}


// MARK: - Main ARView container (non-AR 360 viewer + heirloom card)

struct ARViewContainer: UIViewRepresentable {
    let experience: Experience
    @Binding var isRotationLocked: Bool
    
    func makeUIView(context: Context) -> ARView {
        // Pure 360° viewer (no AR session/passthrough)
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.environment.background = .color(.black)
        arView.renderOptions.insert(.disableAREnvironmentLighting)
        arView.renderOptions.insert(.disableHDR)
        arView.renderOptions.insert(.disableMotionBlur)
        
        // Gestures
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        arView.addGestureRecognizer(pan)
        context.coordinator.panGesture = pan
        
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        arView.addGestureRecognizer(pinch)
        context.coordinator.pinchGesture = pinch
        
        // Wire up coordinator
        context.coordinator.arView = arView
        context.coordinator.isRotationLocked = isRotationLocked
        
        // Build scene, FOV, (touch + inertia only)
        context.coordinator.loadAssets(in: arView, experience: experience)
        context.coordinator.applyFOVForCurrentOrientation()
        context.coordinator.startOrientationObservers()
        context.coordinator.startDeviceMotion()

        // ------- Billboard card preview (floating in front of camera) -------
        Task { @MainActor in
            // Try different image formats to avoid alpha channel issues
            var img: UIImage?
            
            // First try JPG (white background, no alpha channel issues)
            if let jpgImg = UIImage(named: "testImage.jpg") {
                img = jpgImg
                print("✅ Using JPG image with white background")
            }
            // Fallback to solid background PNG
            else if let solidImg = UIImage(named: "testImage_solid") {
                img = solidImg
                print("✅ Using solid background PNG image")
            }
            // Fallback to original PNG
            else if let pngImg = UIImage(named: "testImage") {
                img = pngImg
                print("✅ Using original PNG image")
            }
            
            if let image = img {
                do {
                    let card = try await makeBillboardCard(image: image)
                    card.position = SIMD3<Float>(0.0, 0.0, -0.8) // ~80cm in front of camera

                    // Remove old preview if present
                    if let old = arView.scene.anchors.first(where: { $0.name == "BILLBOARD_ANCHOR" }) {
                        arView.scene.removeAnchor(old)
                    }
                    let anchor = AnchorEntity(world: .zero)
                    anchor.name = "BILLBOARD_ANCHOR"
                    anchor.addChild(card)
                    arView.scene.addAnchor(anchor)
                } catch {
                    print("❌ Billboard card build failed: \(error)")
                }
            } else {
                print("⚠️ No test image found. Add 'testImage' to Assets.xcassets.")
            }
        }
        // -------------------------------------------------------------------

        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.isRotationLocked = isRotationLocked
        context.coordinator.applyFOVForCurrentOrientation()
        
        // When locked, stop inertia and ignore gestures
        if isRotationLocked {
            context.coordinator.stopInertia()
            context.coordinator.panGesture?.isEnabled = false
            context.coordinator.pinchGesture?.isEnabled = false
        } else {
            context.coordinator.panGesture?.isEnabled = true
            context.coordinator.pinchGesture?.isEnabled = true
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    // MARK: - Coordinator
    final class Coordinator {
        weak var arView: ARView?
        private var cancellables = Set<AnyCancellable>()
        
        // Camera state (radians)
        private var yaw:   Float = 0      // around world +Y
        private var pitch: Float = 0      // around local +X
        private let minPitch: Float = -89 * .pi / 180
        private let maxPitch: Float =  89 * .pi / 180
        
        // Device motion control
        private let motionManager = CMMotionManager()
        private var referenceAttitude: CMAttitude?
        private var deviceMotionYaw: Float = 0
        private var deviceMotionPitch: Float = 0
        private var isDeviceMotionEnabled = true
        private var isDraggingDeviceMotion = false
        private var deviceMotionWeight: Float = 1.0 // 0-1, reduced during drag
        
        // Gyro axis mapping tunables
        private let yawSign: Float = -1 // invert left/right so turning left pans left
        private let pitchSign: Float = 1 // keep pitch as-is unless we need to flip later
        private let yawSensitivity: Float = 0.85 // increased responsiveness (+42%)
        private let pitchSensitivity: Float = 0.68 // increased responsiveness (+31%)
        private let deadZone: Float = 0.008 // radians ≈ 0.46° (reduced by 20%)
        
        // Time-constant smoothing parameters (more responsive)
        private let tauYaw: Float = 0.17 // time constant for yaw smoothing (seconds, -23%)
        private let tauPitch: Float = 0.20 // time constant for pitch smoothing (seconds, -20%)
        
        // Spike rejection thresholds
        private let spikeThresholdYaw: Float = 1.0 // radians
        private let spikeThresholdPitch: Float = 0.6 // radians
        
        // Slew-rate limiting (allow quicker turns)
        private let maxYawStepPerSec: Float = 2.9 // rad/s (+32%)
        private let maxPitchStepPerSec: Float = 2.25 // rad/s (+25%)
        
        // Quaternion slerp safety (slightly more responsive)
        private let maxAnglePerSec: Float = 3.1 // rad/s (+24%)
        
        // Ramp-up state for first-tilt jump prevention
        private var rampUpProgress: Float = 0.0
        private let rampUpDuration: Float = 0.175 // 175ms ramp-up
        private var rampUpStartTime: TimeInterval = 0
        
        // Debug flag for testing
        #if DEBUG
        private let debugMotion = false // set to true to print yaw/pitch values
        #endif
        
        // Smoothed motion state
        private var smoothedYaw: Float = 0
        private var smoothedPitch: Float = 0
        
        // Yaw unwrapping state
        private var continuousYaw: Float = 0
        
        // Ring buffer for median filtering (5 samples)
        private var yawBuffer: [Float] = Array(repeating: 0, count: 5)
        private var pitchBuffer: [Float] = Array(repeating: 0, count: 5)
        private var bufferIndex: Int = 0
        
        // Previous smoothed values for spike detection
        private var prevSmoothedYaw: Float = 0
        private var prevSmoothedPitch: Float = 0
        
        // Previous applied quaternion for slerp safety
        private var prevAppliedQuaternion: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        
        // Motion timing state
        private var lastMotionTimestamp: TimeInterval? = nil
        
        // Inertia (drag)
        private var velocityYaw:   Float = 0
        private var velocityPitch: Float = 0
        private var displayLink: CADisplayLink?
        private var lastTimestamp: CFTimeInterval = 0
        private let dampingPerSecond: Float = 6.0 // higher = stops quicker
        private let stopThreshold: Float = 0.02   // rad/s below which we stop
        
        // Gestures
        var panGesture: UIPanGestureRecognizer?
        var pinchGesture: UIPinchGestureRecognizer?
        private var isDragging = false
        var isRotationLocked = false
        
        // ---- Zoom / FOV control ----
        // Current FOVs (degrees); the active one depends on orientation.
        private var portraitVerticalFOV:   Float = 75
        private var landscapeHorizontalFOV: Float = 90
        
        // Clamp range
        private let fovMin: Float = 35
        private let fovMax: Float = 110
        
        // Snap levels (degrees)
        private let portraitLevels:   [Float] = [50, 60, 75, 90]
        private let landscapeLevels:  [Float] = [60, 75, 90, 110]
        
        // Snap behavior
        private let snapWindow:  Float = 1.0   // within this → lock
        private let releaseDelta: Float = 3.0  // must move ≥ this beyond locked level to unlock
        
        private var lockedLevelIndex: Int? = nil // index into current levels
        private var pinchStartFOV: Float = 75
        private var pinchSensitivity: Float = 1.0 // >1 = stronger zoom per pinch
        private var isPinching = false
        
        // Haptics
        private let selectionHaptics = UISelectionFeedbackGenerator()
        
        init() {
            NotificationCenter.default.addObserver(self, selector: #selector(handleRecenter), name: .recenterCamera, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleToggleDeviceMotion), name: .toggleDeviceMotion, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleAppWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
            setupDeviceMotion()
        }
        
        deinit {
            stopInertia()
            stopOrientationObservers()
            stopDeviceMotion()
            weightAnimation?.invalidate()
            weightAnimation = nil
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc private func handleAppDidEnterBackground() {
            stopDeviceMotion()
        }
        
        @objc private func handleAppWillEnterForeground() {
            startDeviceMotion()
        }
        
        @objc private func handleToggleDeviceMotion(_ notification: Notification) {
            guard let isEnabled = notification.object as? Bool else { return }
            isDeviceMotionEnabled = isEnabled
            
            if isEnabled {
                startDeviceMotion()
            } else {
                stopDeviceMotion()
            }
        }
        
        // MARK: Helper Functions
        
        private func median(_ values: [Float]) -> Float {
            let sorted = values.sorted()
            let count = sorted.count
            if count % 2 == 0 {
                return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
            } else {
                return sorted[count / 2]
            }
        }
        
        private func unwrapYaw(_ yaw: Float) -> Float {
            let delta = yaw - continuousYaw
            let wrappedDelta = atan2(sin(delta), cos(delta))
            continuousYaw += wrappedDelta
            return continuousYaw
        }
        
        private func clampSpike(_ value: Float, _ previous: Float, _ threshold: Float) -> Float {
            let delta = value - previous
            if abs(delta) > threshold {
                return previous + (delta > 0 ? threshold : -threshold)
            }
            return value
        }
        
        // MARK: Device Motion
        private func setupDeviceMotion() {
            // Check if device motion is available
            guard motionManager.isDeviceMotionAvailable else {
                print("Device motion not available - disabling tilt control")
                isDeviceMotionEnabled = false
                return
            }
            
            // Configure motion manager
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60 Hz
            motionManager.showsDeviceMovementDisplay = false
            
            // Auto-disable on simulator
            #if targetEnvironment(simulator)
            isDeviceMotionEnabled = false
            print("Running on simulator - disabling device motion")
            #endif
        }
        
        func startDeviceMotion() {
            guard isDeviceMotionEnabled, motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }
            
            motionManager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: .main) { [weak self] motion, error in
                guard let self = self, let motion = motion else { return }
                
                DispatchQueue.main.async {
                    self.handleDeviceMotion(motion)
                }
            }
        }
        
        func stopDeviceMotion() {
            guard motionManager.isDeviceMotionActive else { return }
            motionManager.stopDeviceMotionUpdates()
        }
        
        private func handleDeviceMotion(_ motion: CMDeviceMotion) {
            let currentTime: TimeInterval = motion.timestamp
            
            // Compute dt from motion timestamps
            let dt: Float
            if let lastTimestamp = lastMotionTimestamp {
                dt = Float(currentTime - lastTimestamp)
            } else {
                // First frame - use default dt
                dt = 1.0 / 60.0 // 60 FPS default
            }
            
            // Clamp & validate dt to prevent huge steps
            let clampedDt: Float = max(1.0 / 120.0, min(0.25, dt)) // 120 FPS min, 4 FPS max
            
            // Update timestamp for next frame
            lastMotionTimestamp = currentTime
            
            // Set reference attitude on first motion
            if referenceAttitude == nil {
                referenceAttitude = motion.attitude
                smoothedYaw = 0
                smoothedPitch = 0
                continuousYaw = 0
                prevSmoothedYaw = 0
                prevSmoothedPitch = 0
                rampUpProgress = 0.0
                rampUpStartTime = CACurrentMediaTime()
                return
            }
            
            // Calculate relative attitude - multiply(byInverseOf:) returns Void and mutates receiver
            var rel: CMAttitude = motion.attitude
            rel.multiply(byInverseOf: referenceAttitude!)
            
            // Convert CoreMotion quaternion to rotation matrix for clean axis separation
            let cmQuat: CMQuaternion = rel.quaternion
            let w: Float = Float(cmQuat.w)
            let x: Float = Float(cmQuat.x)
            let y: Float = Float(cmQuat.y)
            let z: Float = Float(cmQuat.z)
            
            // Build rotation matrix from quaternion
            let xx: Float = x * x
            let yy: Float = y * y
            let zz: Float = z * z
            let ww: Float = w * w
            let xy: Float = x * y
            let xz: Float = x * z
            let yz: Float = y * z
            let wx: Float = w * x
            let wy: Float = w * y
            let wz: Float = w * z
            
            // Rotation matrix (row-major)
            let m00: Float = ww + xx - yy - zz
            let m01: Float = 2 * (xy - wz)
            let m02: Float = 2 * (xz + wy)
            let m10: Float = 2 * (xy + wz)
            let m11: Float = ww - xx + yy - zz
            let m12: Float = 2 * (yz - wx)
            let m20: Float = 2 * (xz - wy)
            let m21: Float = 2 * (yz + wx)
            let m22: Float = ww - xx - yy + zz
            
            // Extract forward vector (Z-axis in device space, maps to -Z in world space)
            let forwardX: Float = -m02
            let forwardY: Float = -m12
            let forwardZ: Float = -m22
            
            // Compute yaw via horizontal projection (no pitch/roll bleed)
            let horizontalX: Float = forwardX
            let horizontalZ: Float = forwardZ
            let rawYaw: Float = atan2(horizontalX, horizontalZ)
            
            // Compute pitch independently from forward vector's Y component
            let forwardYClamped: Float = max(-1.0, min(1.0, forwardY))
            let rawPitch: Float = asin(forwardYClamped)
            
            // Apply sign corrections
            let yawAdj: Float = yawSign * rawYaw
            let pitchAdj: Float = pitchSign * rawPitch
            
            // Apply dead zone
            let yawDead: Float = abs(yawAdj) < deadZone ? 0.0 : yawAdj
            let pitchDead: Float = abs(pitchAdj) < deadZone ? 0.0 : pitchAdj
            
            // Apply sensitivity
            let yawSens: Float = yawDead * yawSensitivity
            let pitchSens: Float = pitchDead * pitchSensitivity
            
            // Skip processing if both values are zero after dead zone
            if yawSens == 0.0 && pitchSens == 0.0 {
                return
            }
            
            // 1) Unwrap yaw to continuous angle
            let unwrappedYaw: Float = unwrapYaw(yawSens)
            
            // 2) Add to ring buffer for median filtering
            yawBuffer[bufferIndex] = unwrappedYaw
            pitchBuffer[bufferIndex] = pitchSens
            bufferIndex = (bufferIndex + 1) % 5
            
            // 3) Apply median filtering
            let medianYaw: Float = median(yawBuffer)
            let medianPitch: Float = median(pitchBuffer)
            
            // 4) Spike rejection
            let spikeClampedYaw: Float = clampSpike(medianYaw, prevSmoothedYaw, spikeThresholdYaw)
            let spikeClampedPitch: Float = clampSpike(medianPitch, prevSmoothedPitch, spikeThresholdPitch)
            
            // 5) Slew-rate limiting
            let maxYawStep: Float = maxYawStepPerSec * clampedDt
            let maxPitchStep: Float = maxPitchStepPerSec * clampedDt
            
            let yawDelta: Float = spikeClampedYaw - prevSmoothedYaw
            let pitchDelta: Float = spikeClampedPitch - prevSmoothedPitch
            
            let clampedYawDelta: Float = max(-maxYawStep, min(maxYawStep, yawDelta))
            let clampedPitchDelta: Float = max(-maxPitchStep, min(maxPitchStep, pitchDelta))
            
            let targetYaw: Float = prevSmoothedYaw + clampedYawDelta
            let targetPitch: Float = prevSmoothedPitch + clampedPitchDelta
            
            // 6) Time-constant smoothing (EMA with dt)
            let alphaYaw: Float = 1.0 - exp(-clampedDt / tauYaw)
            let alphaPitch: Float = 1.0 - exp(-clampedDt / tauPitch)
            
            smoothedYaw = smoothedYaw + alphaYaw * (targetYaw - smoothedYaw)
            smoothedPitch = smoothedPitch + alphaPitch * (targetPitch - smoothedPitch)
            
            // 7) Apply ramp-up to prevent first-tilt jump
            let rampElapsed: Float = Float(currentTime - rampUpStartTime)
            rampUpProgress = min(1.0, rampElapsed / rampUpDuration)
            
            let rampedYaw: Float = smoothedYaw * rampUpProgress
            let rampedPitch: Float = smoothedPitch * rampUpProgress
            
            // 8) Clamp pitch to avoid looking past the poles (yaw remains unbounded)
            let maxPitchRad: Float = 75 * .pi / 180 // 75 degrees
            let finalPitch: Float = max(-maxPitchRad, min(maxPitchRad, rampedPitch))
            
            // Update previous values for next frame
            prevSmoothedYaw = smoothedYaw
            prevSmoothedPitch = smoothedPitch
            
            // Debug output (compile-time flag)
            #if DEBUG
            if debugMotion {
                let yawDeg: Float = rampedYaw * 180 / .pi
                let pitchDeg: Float = finalPitch * 180 / .pi
                print("Yaw: \(yawDeg)°, Pitch: \(pitchDeg)°, Ramp: \(rampUpProgress)")
            }
            #endif
            
            // Update device motion values
            deviceMotionYaw = rampedYaw
            deviceMotionPitch = finalPitch
            
            // Update camera with combined motion
            updateCameraWithMotion()
        }
        
        private func updateCameraWithMotion() {
            // Combine device motion with drag offset
            let combinedYaw: Float = deviceMotionYaw + yaw
            let combinedPitch: Float = deviceMotionPitch + pitch
            
            // Clamp pitch
            let clampedPitch: Float = max(minPitch, min(maxPitch, combinedPitch))
            
            // Apply weight based on drag state
            let finalYaw: Float = isDragging ? yaw + (deviceMotionYaw * deviceMotionWeight) : combinedYaw
            let finalPitch: Float = isDragging ? pitch + (deviceMotionPitch * deviceMotionWeight) : clampedPitch
            
            updateCamera(yaw: finalYaw, pitch: finalPitch)
        }
        
        // MARK: Orientation/FOV
        func startOrientationObservers() {
            NotificationCenter.default.addObserver(self, selector: #selector(handleOrientationChanged), name: UIDevice.orientationDidChangeNotification, object: nil)
        }
        func stopOrientationObservers() {
            NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        }
        @objc private func handleOrientationChanged() {
            // Reset lock when orientation changes (levels set changes)
            lockedLevelIndex = nil
            applyFOVForCurrentOrientation()
        }
        
        private func isLandscapeNow() -> Bool {
            guard let v = arView else { return false }
            v.layoutIfNeeded()
            return v.bounds.width >= v.bounds.height
        }
        
        func applyFOVForCurrentOrientation() {
            setFOV(currentFOV(), keepLock: true)
        }
        
        private func currentFOV() -> Float {
            isLandscapeNow() ? landscapeHorizontalFOV : portraitVerticalFOV
        }
        
        private func setFOV(_ fovDeg: Float, keepLock: Bool = false) {
            guard let arView = arView,
                  let cameraAnchor = arView.scene.anchors.first(where: { $0.name == "camera" }),
                  let camEntity = cameraAnchor.children.first,
                  var cam = camEntity.components[PerspectiveCameraComponent.self]
            else { return }
            
            let clamped = max(fovMin, min(fovMax, fovDeg))
            if isLandscapeNow() {
                cam.fieldOfViewOrientation = .horizontal
                cam.fieldOfViewInDegrees = clamped
                landscapeHorizontalFOV = clamped
            } else {
                cam.fieldOfViewOrientation = .vertical
                cam.fieldOfViewInDegrees = clamped
                portraitVerticalFOV = clamped
            }
            camEntity.components[PerspectiveCameraComponent.self] = cam
            
            if !keepLock {
                lockedLevelIndex = nil
            }
        }
        
        // MARK: Pan (trackball) with inertia
        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard !isRotationLocked, let view = g.view else { return }
            switch g.state {
            case .began:
                isDragging = true
                isDraggingDeviceMotion = true
                stopInertia()
                // Gradually reduce device motion weight during drag
                animateDeviceMotionWeight(to: 0.0, duration: 0.2)
            case .changed:
                let t = g.translation(in: view)
                // Resolution-independent mapping (~180° across each axis)
                let yawPerPt:   Float = .pi / Float(view.bounds.width)
                let pitchPerPt: Float = .pi / Float(view.bounds.height)
                
                yaw   += Float(t.x) * yawPerPt            // drag left → look right
                pitch += Float(t.y) * pitchPerPt          // drag up  → look down
                pitch = max(minPitch, min(maxPitch, pitch))
                
                updateCamera(yaw: yaw, pitch: pitch)
                g.setTranslation(.zero, in: view)
                
                // Update angular velocity (pts/s → rad/s)
                let v = g.velocity(in: view)
                velocityYaw   = Float(v.x) * yawPerPt
                velocityPitch = Float(v.y) * pitchPerPt
            case .ended, .cancelled, .failed:
                isDragging = false
                isDraggingDeviceMotion = false
                startInertia()
                // Gradually restore device motion weight after drag
                animateDeviceMotionWeight(to: 1.0, duration: 0.3)
            default:
                break
            }
        }
        
        private func startInertia() {
            guard displayLink == nil, !isRotationLocked else { return }
            lastTimestamp = CACurrentMediaTime()
            let link = CADisplayLink(target: self, selector: #selector(stepInertia(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
        
        func stopInertia() {
            displayLink?.invalidate()
            displayLink = nil
            velocityYaw = 0
            velocityPitch = 0
        }
        
        @objc private func stepInertia(_ link: CADisplayLink) {
            let t = link.timestamp
            let dt = max(1.0/120.0, t - lastTimestamp) // clamp dt
            lastTimestamp = t
            
            // Exponential damping: v *= e^(-k*dt)
            let decay = exp(-Double(dampingPerSecond) * dt)
            velocityYaw   *= Float(decay)
            velocityPitch *= Float(decay)
            
            // Integrate
            yaw   += velocityYaw * Float(dt)
            pitch += velocityPitch * Float(dt)
            pitch = max(minPitch, min(maxPitch, pitch))
            updateCamera(yaw: yaw, pitch: pitch)
            
            // Stop when slow enough
            if abs(velocityYaw) < stopThreshold && abs(velocityPitch) < stopThreshold {
                stopInertia()
            }
        }
        
        // MARK: Recenter
        @objc func handleRecenter() {
            stopInertia()
            yaw = 0
            pitch = 0
            deviceMotionYaw = 0
            deviceMotionPitch = 0
            smoothedYaw = 0
            smoothedPitch = 0
            continuousYaw = 0
            prevSmoothedYaw = 0
            prevSmoothedPitch = 0
            rampUpProgress = 0.0
            rampUpStartTime = CACurrentMediaTime()
            
            // Reset ring buffers
            yawBuffer = Array(repeating: 0, count: 5)
            pitchBuffer = Array(repeating: 0, count: 5)
            bufferIndex = 0
            
            // Reset quaternion state
            prevAppliedQuaternion = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
            
            // Reset motion timing
            lastMotionTimestamp = nil
            
            referenceAttitude = nil // Reset reference for next motion
            updateCamera(yaw: 0, pitch: 0)
        }
        
        // MARK: Device Motion Weight Animation
        private var weightAnimation: CADisplayLink?
        private var animationStartWeight: Float = 0
        private var animationTargetWeight: Float = 0
        private var animationStartTime: TimeInterval = 0
        private var animationDuration: TimeInterval = 0
        
        private func animateDeviceMotionWeight(to targetWeight: Float, duration: TimeInterval) {
            // Stop any existing animation
            weightAnimation?.invalidate()
            
            // Set up new animation
            animationStartWeight = deviceMotionWeight
            animationTargetWeight = targetWeight
            animationStartTime = CACurrentMediaTime()
            animationDuration = duration
            
            // Create and start display link
            let animation = CADisplayLink(target: self, selector: #selector(updateDeviceMotionWeight(_:)))
            animation.add(to: .main, forMode: .common)
            weightAnimation = animation
        }
        
        @objc private func updateDeviceMotionWeight(_ link: CADisplayLink) {
            let currentTime: TimeInterval = CACurrentMediaTime()
            let elapsed: TimeInterval = currentTime - animationStartTime
            let progress: Double = min(1.0, elapsed / animationDuration)
            
            // Ease out cubic
            let easedProgress: Double = 1.0 - pow(1.0 - progress, 3.0)
            let easedFloat: Float = Float(easedProgress)
            
            // Interpolate weight
            let weightDelta: Float = animationTargetWeight - animationStartWeight
            deviceMotionWeight = animationStartWeight + (weightDelta * easedFloat)
            
            if progress >= 1.0 {
                link.invalidate()
                weightAnimation = nil
            }
        }
        
        // MARK: Pinch Zoom with Snap + Haptics
        @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
            guard !isRotationLocked else { return }
            switch g.state {
            case .began:
                isPinching = true
                stopInertia()
                selectionHaptics.prepare()
                pinchStartFOV = currentFOV()
            case .changed:
                // scale>1 => zoom in => reduce FOV. Use sensitivity exponent.
                let scale = Float(g.scale)
                let proposed = clampFOV(pinchStartFOV / pow(scale, pinchSensitivity))
                let snapped = snapFOVIfNeeded(target: proposed)
                setFOV(snapped, keepLock: true)
            case .ended, .cancelled, .failed:
                isPinching = false
            default:
                break
            }
        }
        
        private func clampFOV(_ fov: Float) -> Float {
            max(fovMin, min(fovMax, fov))
        }
        
        private func currentLevels() -> [Float] {
            isLandscapeNow() ? landscapeLevels : portraitLevels
        }
        
        /// Snap with hysteresis
        private func snapFOVIfNeeded(target: Float) -> Float {
            let levels = currentLevels()
            
            if let idx = lockedLevelIndex {
                let lockedLevel = levels[idx]
                if abs(target - lockedLevel) < releaseDelta { return lockedLevel }
                lockedLevelIndex = nil
                return clampFOV(target)
            } else {
                var nearestIndex = 0
                var nearestDist  = Float.greatestFiniteMagnitude
                for (i, level) in levels.enumerated() {
                    let d = abs(target - level)
                    if d < nearestDist { nearestDist = d; nearestIndex = i }
                }
                if nearestDist <= snapWindow {
                    lockedLevelIndex = nearestIndex
                    selectionHaptics.selectionChanged()
                    selectionHaptics.prepare()
                    return levels[nearestIndex]
                } else {
                    return clampFOV(target)
                }
            }
        }
        
        // MARK: Camera + Scene
        private func updateCamera(yaw: Float, pitch: Float) {
            guard let arView = arView,
                  let cameraAnchor = arView.scene.anchors.first(where: { $0.name == "camera" }) else { return }
            
            // Create quaternions for yaw and pitch rotations
            let qYaw: simd_quatf = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0)) // world Y
            let qPitch: simd_quatf = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0)) // local X
            
            // Compose rotations: yaw first, then pitch (consistent with existing drag behavior)
            let targetQuaternion: simd_quatf = simd_normalize(qYaw * qPitch)
            
            // Quaternion slerp safety to prevent snapping
            let angleBetween: Float = acos(max(-1.0, min(1.0, abs(simd_dot(prevAppliedQuaternion, targetQuaternion)))))
            let maxAnglePerFrame: Float = maxAnglePerSec * (1.0 / 60.0) // Assume 60 FPS for safety
            
            let slerpFactor: Float = min(1.0, maxAnglePerFrame / max(angleBetween, 0.001))
            let finalQuaternion: simd_quatf = simd_slerp(prevAppliedQuaternion, targetQuaternion, slerpFactor)
            
            // Update camera anchor orientation
            cameraAnchor.orientation = finalQuaternion
            prevAppliedQuaternion = finalQuaternion
        }
        
        func loadAssets(in arView: ARView, experience: Experience) {
            addCamera(to: arView)
            loadSkybox(in: arView, url: experience.skyboxURL)
            
            // Runtime import: prefer USDZ for reliability in RealityKit
            if experience.modelURL.lowercased().hasSuffix(".usdz") {
                loadModel(in: arView, url: experience.modelURL)
            } else if !experience.modelURL.isEmpty {
                print("⚠️ Model skipped - only USDZ supported (got: \(experience.modelURL))")
            }
        }
        
        private func addCamera(to arView: ARView) {
            let cameraAnchor = AnchorEntity(world: .zero)
            cameraAnchor.name = "camera"
            
            var cam = PerspectiveCameraComponent()
            cam.fieldOfViewOrientation = .vertical
            cam.fieldOfViewInDegrees = portraitVerticalFOV
            
            let cameraEntity = Entity()
            cameraEntity.components[PerspectiveCameraComponent.self] = cam
            cameraAnchor.addChild(cameraEntity)
            arView.scene.addAnchor(cameraAnchor)
            
            updateCamera(yaw: 0, pitch: 0)
        }
        
        // Skydome (equirectangular 2:1)
        func loadSkybox(in arView: ARView, url: String) {
            guard let imageURL = URL(string: url) else { return }
            URLSession.shared.dataTask(with: imageURL) { data, _, _ in
                guard
                    let data = data,
                    let image = UIImage(data: data),
                    let cgImage = image.cgImage
                else { return }
                
                DispatchQueue.main.async {
                    if let old = arView.scene.anchors.first(where: { $0.name == "SKY_ANCHOR" }) {
                        arView.scene.removeAnchor(old)
                    }
                    
                    let mesh = MeshResource.generateSphere(radius: 50.0)
                    let texture: TextureResource
                    do {
                        if #available(iOS 18.0, *) {
                            texture = try TextureResource(
                                image: cgImage,
                                withName: "sky_\(UUID().uuidString)",
                                options: .init(semantic: .color)
                            )
                        } else {
                            texture = try TextureResource.generate(
                                from: cgImage,
                                options: .init(semantic: .color)
                            )
                        }
                    } catch {
                        print("❌ Sky texture creation failed: \(error)")
                        return
                    }
                    
                    var mat = UnlitMaterial()
                    mat.color = .init(tint: .white, texture: .init(texture))
                    
                    let sky = ModelEntity(mesh: mesh, materials: [mat])
                    sky.scale = SIMD3<Float>(-1, 1, 1) // invert normals
                    
                    let skyAnchor = AnchorEntity(world: .zero)
                    skyAnchor.name = "SKY_ANCHOR"
                    skyAnchor.addChild(sky)
                    arView.scene.addAnchor(skyAnchor)
                }
            }.resume()
        }
        
        // USDZ only (optional)
        func loadModel(in arView: ARView, url: String) {
            guard let modelURL = URL(string: url) else { return }
            URLSession.shared.dataTask(with: modelURL) { [weak self] data, _, err in
                guard err == nil, let data = data else { return }
                let ext = modelURL.pathExtension.lowercased()
                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".\(ext)")
                do {
                    try data.write(to: tmp)
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.loadModelFromFile(in: arView, fileURL: tmp)
                    }
                } catch { print("Error saving model: \(error)") }
            }.resume()
        }
        
        private func loadModelFromFile(in arView: ARView, fileURL: URL) {
            Task {
                do {
                    let e = try await Entity(contentsOf: fileURL) // USDZ
                    await MainActor.run {
                        let a = AnchorEntity(world: SIMD3<Float>(0, 0, -2))
                        let b = e.visualBounds(relativeTo: nil)
                        let maxDim = max(b.extents.x, b.extents.y, b.extents.z)
                        let scale: Float = 0.5 / maxDim
                        e.scale = SIMD3<Float>(repeating: scale)
                        a.addChild(e)
                        arView.scene.addAnchor(a)
                    }
                } catch {
                    print("Model load failed - ensure USDZ format")
                }
            }
        }
    }
}
