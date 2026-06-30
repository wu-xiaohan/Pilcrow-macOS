// SPDX-License-Identifier: GPL-3.0-only
//  AudioGenerator.swift
//  Pilcrow for macOS
//
//  Synthesizes looping ambient audio (gentle piano pad, rain-like nature noise)
//  to a temp WAV, so the background-sounds feature works without bundled assets.
//  A real loop dropped into Resources/Sounds (piano.* / nature.*) takes priority.

import Foundation

enum AudioGenerator {
    /// Bundled real loop if present, otherwise a synthesized WAV.
    static func loopURL(for kind: String) -> URL? {
        for ext in ["m4a", "mp3", "wav", "aiff"] {
            if let url = Bundle.main.url(forResource: kind, withExtension: ext, subdirectory: "Sounds")
                ?? Bundle.main.url(forResource: kind, withExtension: ext) {
                return url
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("apostrophe-\(kind).wav")
        if FileManager.default.fileExists(atPath: url.path) { return url }

        let samples: [Int16]
        switch kind {
        case "nature": samples = nature()
        case "piano":  samples = piano()
        default: return nil
        }
        guard let data = wav(samples, sampleRate: 44100) else { return nil }
        try? data.write(to: url)
        return url
    }

    private static func nature() -> [Int16] {
        let sr = 44100, n = sr * 10
        var out = [Int16](); out.reserveCapacity(n)
        var last = 0.0
        var seed: UInt64 = 0x2545F4914F6CDD1D
        func rnd() -> Double {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return Double(Int64(bitPattern: seed)) / Double(Int64.max)
        }
        for _ in 0..<n {
            last = last * 0.96 + rnd() * 0.04          // low-pass → soft rain/wind
            out.append(Int16(max(-1, min(1, last * 3)) * 9000))
        }
        return out
    }

    private static func piano() -> [Int16] {
        let sr = 44100, seconds = 8, n = sr * seconds
        let freqs = [261.63, 329.63, 392.00]           // soft C-major pad
        var out = [Int16](); out.reserveCapacity(n)
        for i in 0..<n {
            let t = Double(i) / Double(sr)
            var s = 0.0
            for f in freqs { s += sin(2 * .pi * f * t) }
            s /= Double(freqs.count)
            let tremolo = 0.6 + 0.4 * sin(2 * .pi * 0.15 * t)
            let env = min(1, t / 0.5) * min(1, (Double(seconds) - t) / 0.5)   // fade ends → clean loop
            out.append(Int16(s * tremolo * env * 7000))
        }
        return out
    }

    private static func wav(_ samples: [Int16], sampleRate: Int) -> Data? {
        var data = Data()
        let dataSize = samples.count * 2
        func u32(_ v: UInt32) -> Data { var x = v.littleEndian; return Data(bytes: &x, count: 4) }
        func u16(_ v: UInt16) -> Data { var x = v.littleEndian; return Data(bytes: &x, count: 2) }
        data.append("RIFF".data(using: .ascii)!); data.append(u32(UInt32(36 + dataSize)))
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!); data.append(u32(16)); data.append(u16(1)); data.append(u16(1))
        data.append(u32(UInt32(sampleRate))); data.append(u32(UInt32(sampleRate * 2)))
        data.append(u16(2)); data.append(u16(16))
        data.append("data".data(using: .ascii)!); data.append(u32(UInt32(dataSize)))
        for s in samples { data.append(u16(UInt16(bitPattern: s))) }
        return data
    }
}
