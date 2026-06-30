// SPDX-License-Identifier: GPL-3.0-only
//  PandocRunner.swift
//  Pilcrow for macOS
//
//  Runs `pandoc` (and locates `typst`/TeX engines) via Process for the live
//  preview and export. Bundled binaries in Resources/Tools take precedence;
//  otherwise common Homebrew/system locations are used. A sane PATH is injected
//  so pandoc can find its PDF engines (GUI apps inherit a minimal PATH).

import Foundation

enum PandocError: LocalizedError {
    case notFound(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let tool): return "\(tool) was not found. Install it with `brew install \(tool)`."
        case .failed(let message): return message
        }
    }
}

enum PandocRunner {
    static let searchPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]

    /// Locates a CLI tool: bundled (Resources/Tools) first, then PATH-like dirs.
    static func tool(_ name: String) -> URL? {
        if let bundled = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Tools"),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }
        for dir in searchPaths {
            let path = dir + "/" + name
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    static func executableURL() -> URL? { tool("pandoc") }
    static var isAvailable: Bool { executableURL() != nil }

    private static func childEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extra = searchPaths.joined(separator: ":")
        env["PATH"] = env["PATH"].map { extra + ":" + $0 } ?? extra
        return env
    }

    /// Runs pandoc with `arguments`, feeding `input` on stdin, returning stdout.
    @discardableResult
    static func run(_ arguments: [String], input: String) throws -> String {
        guard let exe = executableURL() else { throw PandocError.notFound("pandoc") }

        let process = Process()
        process.executableURL = exe
        process.arguments = arguments
        process.environment = childEnvironment()
        // pandoc/typst create temp files in the working directory; a GUI app's
        // CWD is "/" (read-only), so point it at a writable temp directory.
        process.currentDirectoryURL = FileManager.default.temporaryDirectory

        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        // Drain pipes concurrently to avoid buffer deadlock.
        var outData = Data(), errData = Data()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "pandoc.read", attributes: .concurrent)
        group.enter(); queue.async { outData = stdout.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        group.enter(); queue.async { errData = stderr.fileHandleForReading.readDataToEndOfFile(); group.leave() }

        stdin.fileHandleForWriting.write(Data(input.utf8))
        stdin.fileHandleForWriting.closeFile()

        process.waitUntilExit()
        group.wait()

        guard process.terminationStatus == 0 else {
            let message = String(data: errData, encoding: .utf8) ?? "pandoc exited \(process.terminationStatus)"
            throw PandocError.failed(message)
        }
        return String(data: outData, encoding: .utf8) ?? ""
    }

    /// Converts Markdown to a standalone HTML document (used by the preview).
    static func markdownToHTML(_ markdown: String, inputFormat: String = "markdown") throws -> String {
        try run(["--from", inputFormat, "--to", "html", "--standalone", "--mathjax"], input: markdown)
    }
}
