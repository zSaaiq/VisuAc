//
//  PerlinNoise.swift
//  VisuAc
//
//  Created by Kevin Müller on 23.03.25.
//

import Foundation

class PerlinNoise {
    private var permutation: [Int]
    
    init(seed: Int = 0) {
        // Initialize permutation table
        var perm: [Int] = []
        for i in 0..<256 {
            perm.append(i)
        }
        
        // Shuffle permutation table using seed
        var random = seed
        for i in 0..<256 {
            random = (random * 1103515245 + 12345) & 0x7FFFFFFF
            let j = random % 256
            perm.swapAt(i, j)
        }
        
        // Duplicate for easier computation
        permutation = perm + perm
    }
    
    func noise(x: Double, y: Double = 0, z: Double = 0) -> Double {
        // Find unit cube that contains point
        let X = Int(floor(x)) & 255
        let Y = Int(floor(y)) & 255
        let Z = Int(floor(z)) & 255
        
        // Find relative x, y, z of point in cube
        let xf = x - floor(x)
        let yf = y - floor(y)
        let zf = z - floor(z)
        
        // Compute fade curves for each coordinate
        let u = fade(t: xf)
        let v = fade(t: yf)
        let w = fade(t: zf)
        
        // Hash coordinates of the 8 cube corners
        let A = permutation[X] + Y
        let AA = permutation[A] + Z
        let AB = permutation[A + 1] + Z
        let B = permutation[X + 1] + Y
        let BA = permutation[B] + Z
        let BB = permutation[B + 1] + Z
        
        // Blend the 8 corner values based on position within cube
        return lerp(
            t: w,
            a: lerp(
                t: v,
                a: lerp(
                    t: u,
                    a: grad(hash: permutation[AA], x: xf, y: yf, z: zf),
                    b: grad(hash: permutation[BA], x: xf-1, y: yf, z: zf)
                ),
                b: lerp(
                    t: u,
                    a: grad(hash: permutation[AB], x: xf, y: yf-1, z: zf),
                    b: grad(hash: permutation[BB], x: xf-1, y: yf-1, z: zf)
                )
            ),
            b: lerp(
                t: v,
                a: lerp(
                    t: u,
                    a: grad(hash: permutation[AA+1], x: xf, y: yf, z: zf-1),
                    b: grad(hash: permutation[BA+1], x: xf-1, y: yf, z: zf-1)
                ),
                b: lerp(
                    t: u,
                    a: grad(hash: permutation[AB+1], x: xf, y: yf-1, z: zf-1),
                    b: grad(hash: permutation[BB+1], x: xf-1, y: yf-1, z: zf-1)
                )
            )
        )
    }
    
    private func fade(t: Double) -> Double {
        // Fade function as defined by Ken Perlin
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
    
    private func lerp(t: Double, a: Double, b: Double) -> Double {
        // Linear interpolation
        return a + t * (b - a)
    }
    
    private func grad(hash: Int, x: Double, y: Double, z: Double) -> Double {
        // Convert lower 4 bits of hash into 12 gradient directions
        let h = hash & 15
        let u = h < 8 ? x : y
        let v = h < 4 ? y : (h == 12 || h == 14 ? x : z)
        return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v)
    }
}
