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
    glass.metallic = .float(0.0)
    glass.roughness = .float(0.18)

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

        // ------- Heirloom card preview (floating in front of camera) -------
        Task { @MainActor in
            if let img = UIImage(named: "HeirloomCutout") {
                do {
                    let card = try await makeHeirloomCard(image: img)
                    card.position = SIMD3<Float>(0.0, 0.0, -0.6) // ~60cm in front of camera

                    // Remove old preview if present
                    if let old = arView.scene.anchors.first(where: { $0.name == "HEIRLOOM_ANCHOR" }) {
                        arView.scene.removeAnchor(old)
                    }
                    let anchor = AnchorEntity(world: .zero)
                    anchor.name = "HEIRLOOM_ANCHOR"
                    anchor.addChild(card)
                    arView.scene.addAnchor(anchor)
                } catch {
                    print("❌ Heirloom card build failed: \(error)")
                }
            } else {
                print("⚠️ Add a PNG-with-alpha named 'HeirloomCutout' to Assets.xcassets to preview the card.")
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
        private var motionSensitivity: Float = 1.0
        private var motionDeadZone: Float = 0.01 // rad
        private var isDraggingDeviceMotion = false
        private var deviceMotionWeight: Float = 1.0 // 0-1, reduced during drag
        
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
            // Set reference attitude on first motion
            if referenceAttitude == nil {
                referenceAttitude = motion.attitude
                return
            }
            
            // Calculate relative attitude - multiply(byInverseOf:) returns Void and mutates receiver
            var rel: CMAttitude = motion.attitude
            rel.multiply(byInverseOf: referenceAttitude!)
            
            // Extract yaw and pitch (ignore roll to avoid horizon tilt)
            // CoreMotion quaternion: CMQuaternion(x, y, z, w)
            let cmQuat: CMQuaternion = rel.quaternion
            
            // Break up complex math to avoid type-checker timeouts
            let w: Float = Float(cmQuat.w)
            let x: Float = Float(cmQuat.x)
            let y: Float = Float(cmQuat.y)
            let z: Float = Float(cmQuat.z)
            
            // Yaw calculation with explicit intermediate terms
            let t0: Float = 2 * (w * z + x * y)
            let t1: Float = 1 - 2 * (y * y + z * z)
            let yaw: Float = atan2(t0, t1)
            
            // Pitch calculation with clamping
            let t2: Float = 2 * (w * y - z * x)
            let t2c: Float = max(-1.0 as Float, min(1.0 as Float, t2))
            let pitch: Float = asin(t2c)
            
            // Apply sensitivity and dead zone
            let scaledYaw: Float = yaw * motionSensitivity
            let scaledPitch: Float = pitch * motionSensitivity
            
            // Apply dead zone
            if abs(scaledYaw) < motionDeadZone && abs(scaledPitch) < motionDeadZone {
                return
            }
            
            // Update device motion values
            deviceMotionYaw = scaledYaw
            deviceMotionPitch = scaledPitch
            
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
            let composedRotation: simd_quatf = simd_normalize(qYaw * qPitch)
            
            // Update camera anchor orientation
            cameraAnchor.orientation = composedRotation
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
