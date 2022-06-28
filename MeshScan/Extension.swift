//
//  Extension.swift
//  MeshScan
//
//  Created by Leon Teng on 18.08.21.
//

import Foundation
import ARKit

extension  SCNGeometry {
    convenience init(arGeometry: ARMeshGeometry) {
           let verticesSource = SCNGeometrySource(arGeometry.vertices, semantic: .vertex)
           let normalsSource = SCNGeometrySource(arGeometry.normals, semantic: .normal)
           let faces = SCNGeometryElement(arGeometry.faces)
           self.init(sources: [verticesSource, normalsSource], elements: [faces])
    }
}
extension  SCNGeometrySource {
        convenience init(_ source: ARGeometrySource, semantic: Semantic) {
               self.init(buffer: source.buffer, vertexFormat: source.format, semantic: semantic, vertexCount: source.count, dataOffset: source.offset, dataStride: source.stride)
        }
}
extension  SCNGeometryElement {
        convenience init(_ source: ARGeometryElement) {
               let pointer = source.buffer.contents()
               let byteCount = source.count * source.indexCountPerPrimitive * source.bytesPerIndex
               let data = Data(bytesNoCopy: pointer, count: byteCount, deallocator: .none)
               self.init(data: data, primitiveType: .of(source.primitiveType), primitiveCount: source.count, bytesPerIndex: source.bytesPerIndex)
        }
}
extension  SCNGeometryPrimitiveType {
        static  func  of(_ type: ARGeometryPrimitiveType) -> SCNGeometryPrimitiveType {
               switch type {
               case .line:
                       return .line
               case .triangle:
                       return .triangles
               }
        }
}

extension ARMeshClassification {
    var description: String {
        switch self {
        case .ceiling: return "Ceiling"
        case .door: return "Door"
        case .floor: return "Floor"
        case .seat: return "Seat"
        case .table: return "Table"
        case .wall: return "Wall"
        case .window: return "Window"
        case .none: return "None"
        @unknown default: return "Unknown"
        }
    }
    
    var color: UIColor {
        switch self {
        case .ceiling: return .cyan
        case .door: return .brown
        case .floor: return .red
        case .seat: return .purple
        case .table: return .yellow
        case .wall: return .green
        case .window: return .blue
        case .none: return .lightGray
        @unknown default: return .gray
        }
    }
}

extension ARMeshGeometry {
    func vertex(at index: UInt32) -> (Float, Float, Float) {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: (Float, Float, Float).self).pointee
        return vertex
    }
    
    func classificationOf(faceWithIndex index: Int) -> ARMeshClassification {
        guard let classification = classification else { return .none }
        let classificationAddress = classification.buffer.contents().advanced(by: index)
        let classificationValue = Int(classificationAddress.assumingMemoryBound(to: UInt8.self).pointee)
        return ARMeshClassification(rawValue: classificationValue) ?? .none
    }
    
    func vertexIndicesOf(faceWithIndex index: Int) -> [UInt32] {
        let indicesPerFace = faces.indexCountPerPrimitive
        let facesPointer = faces.buffer.contents()
        var vertexIndices = [UInt32]()
        for offset in 0..<indicesPerFace {
            let vertexIndexAddress = facesPointer.advanced(by: (index * indicesPerFace + offset) * MemoryLayout<UInt32>.size)
            vertexIndices.append(UInt32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee))
        }
        return vertexIndices
    }
    
    func verticesOf(faceWithIndex index: Int) -> [(Float, Float, Float)] {
        let vertexIndices = vertexIndicesOf(faceWithIndex: index)
        let vertices = vertexIndices.map { vertex(at: $0) }
        return vertices
    }
    
    func centerOf(faceWithIndex index: Int) -> (Float, Float, Float) {
        let vertices = verticesOf(faceWithIndex: index)
        let sum = vertices.reduce((0, 0, 0)) { ($0.0 + $1.0, $0.1 + $1.1, $0.2 + $1.2) }
        let geometricCenter = (sum.0 / 3, sum.1 / 3, sum.2 / 3)
        return geometricCenter
    }
}

extension float4x4 {
    init(_ matrix: SCNMatrix4) {
        self.init([
            simd_float4(matrix.m11, matrix.m12, matrix.m13, matrix.m14),
            simd_float4(matrix.m21, matrix.m22, matrix.m23, matrix.m24),
            simd_float4(matrix.m31, matrix.m32, matrix.m33, matrix.m34),
            simd_float4(matrix.m41, matrix.m42, matrix.m43, matrix.m44)
            ])
    }
}

extension simd_float4 {
    init(_ vector: SCNVector4) {
        self.init(vector.x, vector.y, vector.z, vector.w)
    }

    init(_ vector: SCNVector3) {
        self.init(vector.x, vector.y, vector.z, 1)
    }
}

extension SCNVector4 {
    init(_ vector: simd_float4) {
        self.init(x: vector.x, y: vector.y, z: vector.z, w: vector.w)
    }
    
    init(_ vector: SCNVector3) {
        self.init(x: vector.x, y: vector.y, z: vector.z, w: 1)
    }
}

extension SCNVector3 {
    init(_ vector: simd_float4) {
        self.init(x: vector.x / vector.w, y: vector.y / vector.w, z: vector.z / vector.w)
    }
}

func * (left: SCNMatrix4, right: SCNVector3) -> SCNVector3 {
    let matrix = float4x4(left)
    let vector = simd_float4(right)
    let result = matrix * vector
    
    return SCNVector3(result)
}
