//
//  ViewController.swift
//  ARKitTestProject
//
//  Created by Artem Chaykovsky on 6/26/17.
//  Copyright © 2017 Onix-Systems. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!

    let session = ARSession()
    var sessionConfig: ARSessionConfiguration = ARWorldTrackingSessionConfiguration()
    var screenCenter: CGPoint?
     var focusSquare: FocusSquare?

    var dragOnInfinitePlanesEnabled = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
      //  sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        session.delegate = self
        
        // Create a new scene
       // let scene = SCNScene(named: "art.scnassets/ship.scn")!
        sceneView.scene.physicsWorld.contactDelegate = self

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
        setupScene()
        setupFocusSquare()
        // Set the scene to the view
       // sceneView.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Create a session configuration
       // let configuration = ARWorldTrackingSessionConfiguration()
       // configuration.planeDetection = .horizontal

        if let worldSessionConfig = sessionConfig as? ARWorldTrackingSessionConfiguration {
            worldSessionConfig.planeDetection = .horizontal
            session.run(worldSessionConfig, options: [.resetTracking, .removeExistingAnchors])
        }

        // Run the view's session
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        session.pause()
    }


    func setupScene() {
        // set up sceneView
        sceneView.delegate = self
        sceneView.session = session
        sceneView.antialiasingMode = .multisampling4X
        sceneView.automaticallyUpdatesLighting = false

        sceneView.preferredFramesPerSecond = 60
        sceneView.contentScaleFactor = 1.3

        if let camera = sceneView.pointOfView?.camera {
            camera.wantsHDR = true
            camera.wantsExposureAdaptation = true
            camera.exposureOffset = -1
            camera.minimumExposure = -1
        }
        DispatchQueue.main.async {
            self.screenCenter = self.sceneView.bounds.mid
        }
    }

    func setupFocusSquare() {
        focusSquare?.isHidden = true
        focusSquare?.removeFromParentNode()
        focusSquare = FocusSquare()
        sceneView.scene.rootNode.addChildNode(focusSquare!)
    }

    func updateFocusSquare() {
        guard let screenCenter = screenCenter else { return }
//
//        if virtualObject != nil && sceneView.isNode(virtualObject!, insideFrustumOf: sceneView.pointOfView!) {
//            focusSquare?.hide()
//        } else {
//            focusSquare?.unhide()
//        }
        focusSquare?.unhide()
        let (worldPos, planeAnchor, _) = worldPositionFromScreenPosition(screenCenter, objectPos: focusSquare?.position)
        if let worldPos = worldPos {
            focusSquare?.update(for: worldPos, planeAnchor: planeAnchor, camera: self.session.currentFrame?.camera)
//            textManager.cancelScheduledMessage(forType: .focusSquare)
        }
    }

    func worldPositionFromScreenPosition(_ position: CGPoint,
                                         objectPos: SCNVector3?,
                                         infinitePlane: Bool = false) -> (position: SCNVector3?, planeAnchor: ARPlaneAnchor?, hitAPlane: Bool) {

        // -------------------------------------------------------------------------------
        // 1. Always do a hit test against exisiting plane anchors first.
        //    (If any such anchors exist & only within their extents.)

        let planeHitTestResults = sceneView.hitTest(position, types: .existingPlaneUsingExtent)
        if let result = planeHitTestResults.first {

            let planeHitTestPosition = SCNVector3.positionFromTransform(result.worldTransform)
            let planeAnchor = result.anchor

            // Return immediately - this is the best possible outcome.
            return (planeHitTestPosition, planeAnchor as? ARPlaneAnchor, true)
        }



//        let featureHitTestResults = sceneView.hitTest(position, types: .featurePoint)
//        if let result = featureHitTestResults.first {
//
//            let planeHitTestPosition = SCNVector3.positionFromTransform(result.worldTransform)
//            let planeAnchor = result.anchor
//
//            // Return immediately - this is the best possible outcome.
//            return (planeHitTestPosition, planeAnchor as? ARPlaneAnchor, true)
//        }



        // -------------------------------------------------------------------------------
        // 2. Collect more information about the environment by hit testing against
        //    the feature point cloud, but do not return the result yet.

        var featureHitTestPosition: SCNVector3?
        var highQualityFeatureHitTestResult = false

        let highQualityfeatureHitTestResults = sceneView.hitTestWithFeatures(position, coneOpeningAngleInDegrees: 18, minDistance: 0.1, maxDistance: 20.0)

        if !highQualityfeatureHitTestResults.isEmpty {
            let result = highQualityfeatureHitTestResults[0]
            featureHitTestPosition = result.position
            highQualityFeatureHitTestResult = true
        }

        // -------------------------------------------------------------------------------
        // 3. If desired or necessary (no good feature hit test result): Hit test
        //    against an infinite, horizontal plane (ignoring the real world).

        if (infinitePlane && dragOnInfinitePlanesEnabled) || !highQualityFeatureHitTestResult {

            let pointOnPlane = objectPos ?? SCNVector3Zero

            let pointOnInfinitePlane = sceneView.hitTestWithInfiniteHorizontalPlane(position, pointOnPlane)
            if pointOnInfinitePlane != nil {
                return (pointOnInfinitePlane, nil, true)
            }
        }

        // -------------------------------------------------------------------------------
        // 4. If available, return the result of the hit test against high quality
        //    features if the hit tests against infinite planes were skipped or no
        //    infinite plane was hit.

        if highQualityFeatureHitTestResult {
            return (featureHitTestPosition, nil, false)
        }

        // -------------------------------------------------------------------------------
        // 5. As a last resort, perform a second, unfiltered hit test against features.
        //    If there are no features in the scene, the result returned here will be nil.

        let unfilteredFeatureHitTestResults = sceneView.hitTestWithFeatures(position)
        if !unfilteredFeatureHitTestResults.isEmpty {
            let result = unfilteredFeatureHitTestResults[0]
            return (result.position, nil, false)
        }

        return (nil, nil, false)
    }


    // MARK: - Actions

    @objc private func tapAction() {
        addLogo()
    }

    fileprivate func addLogo() {
        
        guard let currentFrame = sceneView.session.currentFrame else {
            return
        }

//        let imagePlane = SCNPlane(width: sceneView.bounds.height / 10000,
//                                  height: sceneView.bounds.height / 10000)
        let imagePlane = SCNPlane(width: 0.08,
                                  height: 0.08)
        imagePlane.firstMaterial?.diffuse.contents = UIImage(named: "smile")
        imagePlane.firstMaterial?.lightingModel = .constant

        let planeNode = SCNNode(geometry: imagePlane)
        if let lastFocusSquarePos = self.focusSquare?.lastPosition {
            setNewVirtualObjectPosition(lastFocusSquarePos, object: planeNode)
        }

       // sceneView.scene.rootNode.addChildNode(planeNode)

//        var translation = matrix_identity_float4x4
//        translation.columns.3.z = -0.1
//        planeNode.simdTransform = matrix_multiply(currentFrame.camera.transform, translation)

    }

    var recentVirtualObjectDistances = [CGFloat]()

    func setNewVirtualObjectPosition(_ pos: SCNVector3, object: SCNNode) {

        guard let cameraTransform = session.currentFrame?.camera.transform else {
            return
        }

        var translation = matrix_identity_float4x4
        object.simdTransform = matrix_multiply(cameraTransform, translation)

        recentVirtualObjectDistances.removeAll()

        let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
        var cameraToPosition = pos - cameraWorldPos

        // Limit the distance of the object from the camera to a maximum of 10 meters.
        cameraToPosition.setMaximumLength(30)

        object.position = cameraWorldPos + cameraToPosition

        if object.parent == nil {
            sceneView.scene.rootNode.addChildNode(object)
        }
//        var translation = matrix_identity_float4x4
//        translation.columns.3.z = -cameraToPosition.length()
//        object.simdTransform = matrix_multiply(cameraTransform, translation)
    }

    
    // MARK: - ARSCNViewDelegate

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        updateFocusSquare()
    }

    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
               // self.addPlane(node: node, anchor: planeAnchor)
               // self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
            }
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {

    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}



// MARK: - SCNPhysicsContactDelegate

extension ViewController: SCNPhysicsContactDelegate {

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {

    }
}

