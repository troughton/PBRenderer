//
//  LightGrid.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 31/05/16.
//
//

import Foundation

struct LightGridEntry {
    let sizeAndLink : UInt32; // uint8 size, uint24 link
    let lightIndexX : UInt32
    let lightIndexY : UInt32
    let lightIndexZ : UInt32
}

struct LightGridDimensions {
    let width : Int;
    let height : Int;
    let depth : Int;
    
    // cell: 4x4x4 entries or 2x2x1 packed entries
    func cellIndex(x: Int, y: Int, z: Int) -> Int {
    assert(((width | height | depth) % 4 == 0), "dimensions must be cell-aligned");
        
    assert(x >= 0 && y >= 0 && z >= 0);
    assert(x < width / 4 && y < height / 4 && z < depth / 4);
    
    return (y*width / 4 + x)*depth / 4 + z;
    }
}


func swapWordPair(_ pair: UInt32) -> UInt32 {
    return (pair << 16) | (pair >> 16)
}

final class LightGridBuilder {
    var dim = LightGridDimensions(width: 0, height: 0, depth: 0)
    private var lightIndexLists = [[Int32]]()
    private var coverageLists = [[UInt64]]()
    private var tempBuffer = [UInt8]()
    private var allocatedBytes : size_t = 0
    
    
    let fineIndexTable =
        [
            [ 0, 1, 4, 5 ],
            [ 2, 3, 6, 7 ],
            [ 8, 9, 12, 13 ],
            [ 10, 11, 14, 15 ],
            ];
    func getFineIndex(_ xx: Int, _ yy: Int) -> Int {

        return fineIndexTable[yy][xx];
    }

    var cellCount : size_t {
        assert(lightIndexLists.count == coverageLists.count)
        return lightIndexLists.count
    }
    
    func buildFlatEntries(x _x: Int, y _y: Int, z _z: Int) {
        let cellIndex = dim.cellIndex(x: _x, y: _y, z: _z);
        let count = lightIndexLists[cellIndex].count
        assert(count == coverageLists[cellIndex].count);
        
        if count == 0  {
            for entryIndex in 0..<64 {
                let yy = entryIndex / 16;
                let xx = (entryIndex / 4) % 4;
                let zz = entryIndex % 4;
                
                let x = _x * 4 + xx;
                let y = _y * 4 + yy;
                let z = _z * 4 + zz;
                
                let headerIndex = (y*dim.width + x)*dim.depth + z;
                let entryPtr = tempBuffer.withUnsafeMutableBufferPointer({ (tempBuffer) -> UnsafeMutablePointer<UInt32>  in
                    let element = tempBuffer.baseAddress?.advanced(by: 16 * headerIndex)
                    return UnsafeMutablePointer<UInt32>(element!)
                })
                
                entryPtr.pointee = 0; // list size: 0
            }
            return;
        }
        
        
        let lightIndexListPtr = lightIndexLists[cellIndex].withUnsafeMutableBufferPointer { (array) -> UnsafeMutablePointer<Int32>? in
                let baseAddress = array.baseAddress
            return baseAddress
        }
        
        let coverageListPtr = coverageLists[cellIndex].withUnsafeMutableBufferPointer { (array) -> UnsafeMutablePointer<UInt32>? in
            let baseAddress = UnsafeMutablePointer<UInt32>(array.baseAddress)
            return baseAddress
        }
        
        
        for entryIndex in 0..<64 {
            let yy = entryIndex / 16;
            let xx = (entryIndex / 4) % 4;
            let zz = entryIndex % 4;
            
            let x = _x * 4 + xx;
            let y = _y * 4 + yy;
            let z = _z * 4 + zz;
            
            let headerIndex = (y*dim.width + x)*dim.depth + z;
            
            let entryPtr = tempBuffer.withUnsafeMutableBufferPointer({ (tempBuffer) -> UnsafeMutablePointer<UInt32>  in
                let element = tempBuffer.baseAddress?.advanced(by: 16 * headerIndex)
                return UnsafeMutablePointer<UInt32>(element!)
            })
            let tailPtr = tempBuffer.withUnsafeMutableBufferPointer({ (tempBuffer) -> UnsafeMutablePointer<UInt16>  in
                let element = tempBuffer.baseAddress?.advanced(by: allocatedBytes)
                return UnsafeMutablePointer<UInt16>(element!)
            })
            
            let fineIndex = self.getFineIndex(xx, yy) * 4 + zz;
            let mask = 1 << fineIndex;
            var sub_mask = UInt32(mask & 0xFFFFFFFF);
            var sub_coverageList_ptr = coverageListPtr;
            
            if sub_mask == 0 {
                sub_mask = UInt32((mask >> 32) & 0xFFFFFFFF);
                sub_coverageList_ptr = sub_coverageList_ptr?.successor()
            }
            
            var cursor = 0;
            for k in 0..<count {
                tailPtr[cursor] = UInt16(lightIndexListPtr![k]);
                cursor += ((sub_coverageList_ptr![k * 2] & sub_mask) != 0) ? 1 : 0
            }
            
            entryPtr[1] = swapWordPair(UnsafePointer<UInt32>(tailPtr.advanced(by: cursor - 2)).pointee)
            entryPtr[2] = swapWordPair(UnsafePointer<UInt32>(tailPtr.advanced(by: cursor - 4)).pointee)
            entryPtr[3] = swapWordPair(UnsafePointer<UInt32>(tailPtr.advanced(by: cursor - 6)).pointee)
            
            let list_size = cursor;
            assert(list_size < 0x100);
            assert(allocatedBytes / 16 < 0x1000000);
            entryPtr[0] = UInt32(((allocatedBytes / 16) << 8) | list_size);
            
            self.allocatedBytes += (max(size_t(6), list_size) - 6 + 7) / 8 * 16;
        }
    }
    
        // packedCells: 2x2x1 packed entries per cell, with 16-bit coverage mask
    func reset(dim: LightGridDimensions) {
        self.dim = dim;
        let cellCount = dim.width * dim.height * dim.depth / 64;
        lightIndexLists = [[Int32]](repeating: [Int32](), count: cellCount)
        coverageLists = [[UInt64]](repeating: [UInt64](), count: cellCount)
    }
    
    func clearAllFragments() {
        for i in 0..<cellCount {
            lightIndexLists[i].removeAll(keepingCapacity: true)
            coverageLists[i].removeAll(keepingCapacity: true)
        }
    }
    
    func pushFragment(cellIndex: Int, lightIndex: Int32, coverage: UInt64) {
        guard coverage != 0 else { return }
        
        lightIndexLists[cellIndex].append(lightIndex)
        coverageLists[cellIndex].append(coverage)
    }
    
    func buildAndUpload(gpuBuffer: UnsafeMutablePointer<Void>, bufferSize: Int) {
        tempBuffer.reserveCapacity(bufferSize + 256 * 1024); // 256 KB margin: max allocation per cell
        
        let tempBufferPtr = tempBuffer.withUnsafeMutableBufferPointer { return $0 }
        
        let headerBytes = self.cellCount * 64 * 16; // uint4: 16 bytes per entry
        allocatedBytes = headerBytes;
        var uploadedBytes = headerBytes;
        
        for y in 0..<dim.height/4 {
            for x in 0..<dim.width/4 {
                for z in 0..<dim.depth / 4 {
                    self.buildFlatEntries(x: x, y: y, z: z);
                    
                    let size = allocatedBytes - uploadedBytes
                    if size > 0 {
                        memcpy(gpuBuffer.advanced(by: uploadedBytes), tempBufferPtr.baseAddress?.advanced(by: uploadedBytes), allocatedBytes - uploadedBytes);
                        
                        uploadedBytes = allocatedBytes;
                        
                        assert(allocatedBytes <= bufferSize, "gpu buffer not big enough");
                    }
                    
                }
            }
        }
        
        memcpy(gpuBuffer, tempBufferPtr.baseAddress, headerBytes);
    }
    
}
