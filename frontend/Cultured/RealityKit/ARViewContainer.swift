// ARViewContainer.swift
import SwiftUI
import RealityKit
import Combine
import CoreMotion
import QuartzCore

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
        }
        
        deinit {
            stopInertia()
            stopOrientationObservers()
            NotificationCenter.default.removeObserver(self)
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
                stopInertia()
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
                startInertia()
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
            updateCamera(yaw: 0, pitch: 0)
        }
        
        // MARK: Pinch Zoom with Snap + Haptics
        @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
            guard !isRotationLocked else { return }   // ← removed unused 'view'
            
            switch g.state {
            case .began:
                isPinching = true
                stopInertia()
                selectionHaptics.prepare()
                // removed: lockedLevelIndex = lockedLevelIndex (self-assignment)
                pinchStartFOV = currentFOV()
            case .changed:
                // scale>1 => zoom in => reduce FOV. Use sensitivity exponent.
                let scale = Float(g.scale)
                let proposed = clampFOV(pinchStartFOV / pow(scale, pinchSensitivity))
                let snapped = snapFOVIfNeeded(target: proposed)
                setFOV(snapped, keepLock: true)
                // cumulative behavior from start (no g.scale reset)
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
        
        /// Snap with hysteresis: enter lock when within snapWindow of a level, but
        /// require moving ≥ releaseDelta away to unlock.
        private func snapFOVIfNeeded(target: Float) -> Float {
            let levels = currentLevels()
            
            if let idx = lockedLevelIndex {
                let lockedLevel = levels[idx]
                // Stay locked until user moves far enough away
                if abs(target - lockedLevel) < releaseDelta {
                    return lockedLevel
                } else {
                    // Unlock and return free target (still clamped)
                    lockedLevelIndex = nil
                    return clampFOV(target)
                }
            } else {
                // Not currently locked: see if we're within the snap window of any level
                var nearestIndex = 0
                var nearestDist  = Float.greatestFiniteMagnitude
                for (i, level) in levels.enumerated() {
                    let d = abs(target - level)
                    if d < nearestDist {
                        nearestDist = d
                        nearestIndex = i
                    }
                }
                if nearestDist <= snapWindow {
                    lockedLevelIndex = nearestIndex
                    selectionHaptics.selectionChanged() // haptic on lock
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
            let qYaw   = simd_quatf(angle: yaw,   axis: [0, 1, 0]) // world Y
            let qPitch = simd_quatf(angle: pitch, axis: [1, 0, 0]) // local X
            cameraAnchor.orientation = simd_normalize(qYaw * qPitch)
        }
        
        func loadAssets(in arView: ARView, experience: Experience) {
            addCamera(to: arView)
            loadSkybox(in: arView, url: experience.skyboxURL)
            
            // Runtime import: prefer USDZ for reliability in RealityKit
            if experience.modelURL.lowercased().hasSuffix(".usdz") {
                loadModel(in: arView, url: experience.modelURL)
            } else {
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
                    sky.scale = [-1, 1, 1] // invert normals
                    
                    let skyAnchor = AnchorEntity(world: .zero)
                    skyAnchor.name = "SKY_ANCHOR"
                    skyAnchor.addChild(sky)
                    arView.scene.addAnchor(skyAnchor)
                }
            }.resume()
        }
        
        // USDZ only
        func loadModel(in arView: ARView, url: String) {
            guard let modelURL = URL(string: url) else { return }
            URLSession.shared.dataTask(with: modelURL) { [weak self] data, _, err in
                guard err == nil, let data = data else { return } // ← no early self binding
                
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
                        let a = AnchorEntity(world: [0, 0, -2])
                        let b = e.visualBounds(relativeTo: nil)
                        let maxDim = max(b.extents.x, b.extents.y, b.extents.z)
                        let scale: Float = 0.5 / maxDim
                        e.scale = [scale, scale, scale]
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
