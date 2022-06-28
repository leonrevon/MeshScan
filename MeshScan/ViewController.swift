//
//  ViewController.swift
//  MeshScan
//
//  Created by Leon Teng on 23.11.21.
//

import UIKit
import ARKit
import SceneKit

class ViewController: UIViewController, ARSessionDelegate, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        //sceneView.automaticallyConfigureSession = false;
        sceneView.debugOptions.insert(.renderAsWireframe)
        
        //sceneView.debugOptions.insert(.showSceneUnderstanding)
        //sceneView.environment.sceneUnderstanding.options.insert(.occlusion)
        //sceneView.environment.sceneUnderstanding.options.insert(.physics)
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
    }
    
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        /*guard let meshAnchors = anchors as? [ARMeshAnchor] else {
            return }
        meshAnchors.forEach( {
            meshAnchor in
            var floorIndices = [UInt32]()
            let arGeometry = meshAnchor.geometry;
            let verticesSource = SCNGeometrySource(arGeometry.vertices, semantic: .vertex)
            let normalSource = SCNGeometrySource(arGeometry.normals, semantic: .normal)
            let fc = arGeometry.faces.count
            for index in 0..<fc{
                let classification = arGeometry.classificationOf(faceWithIndex: index)
                let indices = arGeometry.vertexIndicesOf(faceWithIndex: index)
                for i in 0..<indices.count{
                    let vertextIndex = indices[i]
                    if (classification.description == "Seat"){
                        floorIndices.append(vertextIndex)
                        print("\(meshAnchor.identifier)")
                        print(classification.description)
                    }
                }
            }
            
            let floorElement = SCNGeometryElement(indices: floorIndices, primitiveType: .triangles)
            //floorElement.pointSize = 1
            //floorElement.minimumPointScreenSpaceRadius = 1
            //floorElement.maximumPointScreenSpaceRadius = 10
            let floorGeometry = SCNGeometry(sources: [verticesSource, normalSource], elements: [floorElement])
            floorGeometry.firstMaterial?.diffuse.contents = UIColor.red
            let floorNode = SCNNode(geometry: floorGeometry)
            floorNode.name = "Floor-\(meshAnchor.identifier)"
            sceneView.scene.rootNode.addChildNode(floorNode)
            
        })*/
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]){
        /* guard let meshAnchors = anchors as? [ARMeshAnchor] else {
            return }
        meshAnchors.forEach( {
            meshAnchor in
        
            var floorIndices = [UInt32]()
            let arGeometry = meshAnchor.geometry;
            let verticesSource = SCNGeometrySource(arGeometry.vertices, semantic: .vertex)
            let normalSource = SCNGeometrySource(arGeometry.normals, semantic: .normal)
            let fc = arGeometry.faces.count
            for index in 0..<fc{
                let classification = arGeometry.classificationOf(faceWithIndex: index)
                let indices = arGeometry.vertexIndicesOf(faceWithIndex: index)
                for i in 0..<indices.count{
                    let vertextIndex = indices[i]
                    if (classification.description == "Seat"){
                        floorIndices.append(vertextIndex)
                        print("\(meshAnchor.identifier)")
                        print(classification.description)
                    }
                }
            }
            
            let floorElement = SCNGeometryElement(indices: floorIndices, primitiveType: .triangles)
            //floorElement.pointSize = 1
            //floorElement.minimumPointScreenSpaceRadius = 1
            //floorElement.maximumPointScreenSpaceRadius = 10
            let floorGeometry = SCNGeometry(sources: [verticesSource, normalSource], elements: [floorElement])
            floorGeometry.firstMaterial?.diffuse.contents = UIColor.red
            let floorNode = sceneView.scene.rootNode.childNode(withName: "Floor-\(meshAnchor.identifier)", recursively: false)
            floorNode?.geometry = floorGeometry
        }) */
    }
    struct NodeData {
        var vertices: [SCNVector3],
            indices: [UInt32]
    }
    
    private var knownNodes = ThreadSafeDictionary<String, NodeData>()
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.global().async {
            guard
                let meshAchor = anchor as? ARMeshAnchor
            else { return }
            
            print("\(anchor.identifier) - Added")
            var vertices = [SCNVector3]()
            var indices = [UInt32]()
            let arGeometry = meshAchor.geometry
            let verticesSource = SCNGeometrySource(arGeometry.vertices, semantic: .vertex)
            let camera = self.sceneView.pointOfView
            if (camera != nil) {
                let cameraPos = simd_float3(x: camera!.position.x, y: camera!.position.y, z: camera!.position.z)
                let worldTr = node.worldTransform
                for index in 0..<verticesSource.vectorCount {
                    let v = arGeometry.vertex(at: UInt32(index))
                    let p1 = SCNVector3(x: v.0, y: v.1, z: v.2)
                    let p2 = worldTr * p1
                    let d = distance(cameraPos, simd_float3(p2))
                    if d < 1 {
                        //print("pos: \(p1) vec: \(p2) dist: \(d)")
                        vertices.append(p1)
                        indices.append(UInt32(vertices.count - 1))
                    }
                }
            }
            let element = SCNGeometryElement(indices: indices, primitiveType: .point)
            element.pointSize = 1
            element.minimumPointScreenSpaceRadius = 1
            element.maximumPointScreenSpaceRadius = 10
            let source = SCNGeometrySource.init(vertices: vertices)
            let meshGeometry = SCNGeometry(sources: [source], elements: [element])
            meshGeometry.firstMaterial?.diffuse.contents = UIColor.red
            let meshNode = SCNNode(geometry: meshGeometry)
            node.addChildNode(meshNode)
            let nd = NodeData(vertices: vertices, indices: indices)
            print("new node \(anchor.identifier) vertices: \(nd.vertices.count) indices:\(nd.indices.count)")
            self.knownNodes[anchor.identifier.uuidString] = nd
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.global().async {
            guard
                let meshAchor = anchor as? ARMeshAnchor,
                let meshNode = node.childNodes.first,
                var nodeData = self.knownNodes[anchor.identifier.uuidString]
            else { return }
            print("\(anchor.identifier.uuidString) - Update")
            let arGeometry = meshAchor.geometry
            let verticesSource = SCNGeometrySource(arGeometry.vertices, semantic: .vertex)
            let camera = self.sceneView.pointOfView
            if (camera != nil) {
                let cameraPos = simd_float3(x: camera!.position.x, y: camera!.position.y, z: camera!.position.z)
                let worldTr = node.worldTransform
                for index in 0..<verticesSource.vectorCount {
                    let v = arGeometry.vertex(at: UInt32(index))
                    let p1 = SCNVector3(x: v.0, y: v.1, z: v.2)
                    let p2 = worldTr * p1
                    let d = distance(cameraPos, simd_float3(p2))
                    //print("cam: \(cameraPos) vec: \(p) dist: \(d)")
                    if d < 1 {
                        if (!nodeData.vertices.contains(where: {$0.x == p1.x && $0.y == p1.y && $0.z == p1.z})) {
                            nodeData.vertices.append(p1)
                            nodeData.indices.append(UInt32(nodeData.vertices.count - 1))
                        }
                    }
                }
                
            }
            let element = SCNGeometryElement(indices: nodeData.indices, primitiveType: .point)
            element.pointSize = 1
            element.minimumPointScreenSpaceRadius = 1
            element.maximumPointScreenSpaceRadius = 10
            let source = SCNGeometrySource(vertices: nodeData.vertices)
            let meshGeometry = SCNGeometry(sources: [source], elements: [element])
            meshGeometry.firstMaterial?.diffuse.contents = UIColor.red
            meshNode.geometry = meshGeometry
            self.knownNodes[anchor.identifier.uuidString] = nodeData
        }
    }
    

    // MARK: - ARSCNViewDelegate

    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
     let node = SCNNode()
     
     return node
     }
     */




    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }

    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
}
