import SwiftUI
import RealityKit
import Combine
import CoreMotion

struct ARViewContainer: UIViewRepresentable {
    let experience: Experience
    @Binding var isRotationLocked: Bool
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.environment.background = .color(.black)
        
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        arView.addGestureRecognizer(panGesture)
        
        context.coordinator.arView = arView
        context.coordinator.isRotationLocked = isRotationLocked
        context.coordinator.startMotionUpdates()
        context.coordinator.loadAssets(in: arView, experience: experience)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.isRotationLocked = isRotationLocked
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        private var cancellables = Set<AnyCancellable>()
        weak var arView: ARView?
        
        private var currentRotationX: Float = 0
        private var currentRotationY: Float = 0
        
        private let motionManager = CMMotionManager()
        private var lastAttitude: CMAttitude?
        var isRotationLocked = false
        private var isDragging = false
        
        private let minRotationX: Float = -89 * .pi / 180
        private let maxRotationX: Float = 89 * .pi / 180
        
        init() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleRecenter),
                name: .recenterCamera,
                object: nil
            )
        }
        
        deinit {
            stopMotionUpdates()
            NotificationCenter.default.removeObserver(self)
        }
        
        func startMotionUpdates() {
            guard motionManager.isDeviceMotionAvailable else {
                print("Gyroscope not available")
                return
            }
            
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let self = self, let motion = motion else { return }
                
                if self.isRotationLocked { return }
                
                if self.lastAttitude == nil {
                    self.lastAttitude = motion.attitude.copy() as? CMAttitude
                    return
                }
                
                guard let last = self.lastAttitude else { return }
                
                let current = motion.attitude.copy() as! CMAttitude
                current.multiply(byInverseOf: last)
                
                self.lastAttitude = motion.attitude.copy() as? CMAttitude
                
                if !self.isDragging {
                    self.currentRotationY -= Float(current.yaw)
                    self.currentRotationX += Float(current.pitch)
                    self.currentRotationX = max(self.minRotationX, min(self.maxRotationX, self.currentRotationX))
                    
                    self.updateCamera()
                }
            }
        }
        
        func stopMotionUpdates() {
            motionManager.stopDeviceMotionUpdates()
        }
        
        @objc func handleRecenter() {
            currentRotationX = 0
            currentRotationY = 0
            lastAttitude = nil
            updateCamera()
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard !isRotationLocked else { return }
            
            switch gesture.state {
            case .began:
                isDragging = true
                
            case .changed:
                let translation = gesture.translation(in: gesture.view)
                
                let rotationSpeed: Float = 0.005
                currentRotationY += Float(translation.x) * rotationSpeed
                currentRotationX -= Float(translation.y) * rotationSpeed
                currentRotationX = max(minRotationX, min(maxRotationX, currentRotationX))
                
                updateCamera()
                gesture.setTranslation(.zero, in: gesture.view)
                
            case .ended, .cancelled, .failed:
                isDragging = false
                
            default:
                break
            }
        }
        
        func updateCamera() {
            guard let arView = arView,
                  let cameraAnchor = arView.scene.anchors.first(where: { $0.name == "camera" }) else {
                return
            }
            
            let yawQuat = simd_quatf(angle: currentRotationY, axis: [0, 1, 0])
            let pitchQuat = simd_quatf(angle: currentRotationX, axis: [1, 0, 0])
            
            cameraAnchor.orientation = yawQuat * pitchQuat
        }
        
        func loadAssets(in arView: ARView, experience: Experience) {
            addCamera(to: arView)
            loadSkybox(in: arView, url: experience.skyboxURL)
            
            if experience.modelURL.lowercased().hasSuffix(".usdz") {
                loadModel(in: arView, url: experience.modelURL)
            } else {
                print("⚠️ Model skipped - only USDZ supported (got: \(experience.modelURL))")
            }
        }
        
        func addCamera(to arView: ARView) {
            let cameraAnchor = AnchorEntity(world: .zero)
            cameraAnchor.name = "camera"
            
            var camera = PerspectiveCameraComponent()
            camera.fieldOfViewInDegrees = 75.0
            
            let cameraEntity = Entity()
            cameraEntity.components[PerspectiveCameraComponent.self] = camera
            
            cameraAnchor.addChild(cameraEntity)
            arView.scene.addAnchor(cameraAnchor)
            
            updateCamera()
        }
        
        func loadSkybox(in arView: ARView, url: String) {
            guard let imageURL = URL(string: url) else { return }
            
            URLSession.shared.dataTask(with: imageURL) { data, response, error in
                guard let data = data, let image = UIImage(data: data) else { return }
                
                DispatchQueue.main.async {
                    let mesh = MeshResource.generateSphere(radius: 50)
                    
                    if let cgImage = image.cgImage,
                       let texture = try? TextureResource(image: cgImage, options: .init(semantic: .color)) {
                        
                        var material = UnlitMaterial()
                        material.color = .init(texture: .init(texture))
                        
                        let skyboxEntity = ModelEntity(mesh: mesh, materials: [material])
                        skyboxEntity.scale = SIMD3<Float>(x: -1, y: 1, z: 1)
                        
                        let anchor = AnchorEntity(world: .zero)
                        anchor.addChild(skyboxEntity)
                        arView.scene.addAnchor(anchor)
                    }
                }
            }.resume()
        }
        
        func loadModel(in arView: ARView, url: String) {
            guard let modelURL = URL(string: url) else { return }
            
            URLSession.shared.dataTask(with: modelURL) { data, response, error in
                guard let data = data else { return }
                
                let ext = modelURL.pathExtension.lowercased()
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".\(ext)")
                
                do {
                    try data.write(to: tempURL)
                    
                    DispatchQueue.main.async {
                        self.loadModelFromFile(in: arView, fileURL: tempURL)
                    }
                } catch {
                    print("Error saving model: \(error)")
                }
            }.resume()
        }
        
        func loadModelFromFile(in arView: ARView, fileURL: URL) {
            Task {
                do {
                    let entity = try await Entity(contentsOf: fileURL)
                    
                    await MainActor.run {
                        let anchor = AnchorEntity(world: [0, 0, -2])
                        
                        let bounds = entity.visualBounds(relativeTo: nil)
                        let maxDim = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
                        let scale = 0.5 / maxDim
                        entity.scale = [scale, scale, scale]
                        
                        anchor.addChild(entity)
                        arView.scene.addAnchor(anchor)
                    }
                } catch {
                    print("Model load failed - convert GLB to USDZ")
                }
            }
        }
    }
}
