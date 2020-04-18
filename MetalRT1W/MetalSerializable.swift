//
//  MetalSerializable.swift
//  MetalRT1W
//
//  Created by Ye Kuang on 2020/04/15.
//  Copyright © 2020 zkk. All rights reserved.
//

import Foundation
import Metal

protocol MetalSerializable {
    var bytesOnMetal: Int32 { get}
    func serialize(to strm: MetalSerializableWriteStream)
}

class MetalSerializableWriteStream {
    private var buffer: MTLBuffer
    private var offs: Int

    init(_ b: MTLBuffer) {
        buffer = b
        offs = 0
    }
    
    static func getBytesRequired(_ m: MetalSerializable) -> Int {
        // The first Int32 stores the size of |m|
        return MemoryLayout.size(ofValue: m.bytesOnMetal) + Int(m.bytesOnMetal)
    }
    
    @discardableResult
    func append(_ ms: MetalSerializable) -> Int {
        let result = memCpy(data: ms.bytesOnMetal)
        ms.serialize(to: self)
        return result
    }
    
    @discardableResult
    func memCpy<T>(data: T) -> Int {
        let rawPtr = buffer.contents().advanced(by: offs)
        rawPtr.bindMemory(to: T.self, capacity: 1).pointee = data
        
        let result = offs
        offs += MemoryLayout<T>.stride
        
        if offs > buffer.length {
            fatalError("Buffer overflow, limit=\(buffer.length) next=\(offs)")
        }
        return result
    }

    func rewind() {
        offs = 0
    }
}
