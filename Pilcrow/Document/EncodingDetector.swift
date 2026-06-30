// SPDX-License-Identifier: GPL-3.0-only
//  EncodingDetector.swift
//  Pilcrow for macOS
//
//  Decodes file data on open: UTF-8 → UTF-16 (by BOM) → Windows-1252 →
//  Mac Roman → Latin-1, stripping any leading BOM and rejecting binary data so
//  a non-text file surfaces a read error instead of mojibake.

import Foundation

enum EncodingDetector {
    static func decode(_ data: Data) -> (text: String, encoding: String.Encoding)? {
        if data.isEmpty { return ("", .utf8) }

        // UTF-8, but reject NUL bytes (those indicate UTF-16/binary, not UTF-8).
        if let s = String(data: data, encoding: .utf8), !s.contains("\0") {
            return (stripBOM(s), .utf8)
        }

        // UTF-16 by byte-order mark.
        let bom = [UInt8](data.prefix(2))
        if bom.count == 2 {
            if bom[0] == 0xFF, bom[1] == 0xFE, let s = String(data: data, encoding: .utf16LittleEndian) {
                return (stripBOM(s), .utf16LittleEndian)
            }
            if bom[0] == 0xFE, bom[1] == 0xFF, let s = String(data: data, encoding: .utf16BigEndian) {
                return (stripBOM(s), .utf16BigEndian)
            }
        }

        // Don't lossily decode binary data as single-byte text.
        if looksBinary(data) { return nil }

        for encoding in [String.Encoding.windowsCP1252, .macOSRoman, .isoLatin1] {
            if let s = String(data: data, encoding: encoding) { return (stripBOM(s), encoding) }
        }
        return nil
    }

    private static func stripBOM(_ s: String) -> String {
        s.hasPrefix("\u{FEFF}") ? String(s.dropFirst()) : s
    }

    /// Heuristic: NUL byte, or >30% C0 control bytes (excluding tab/newline/CR).
    private static func looksBinary(_ data: Data) -> Bool {
        let sample = data.prefix(8000)
        if sample.contains(0x00) { return true }
        let control = sample.reduce(0) { count, b in
            (b < 0x09 || (b > 0x0D && b < 0x20)) ? count + 1 : count
        }
        return Double(control) / Double(max(1, sample.count)) > 0.30
    }
}
