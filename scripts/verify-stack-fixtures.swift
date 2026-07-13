#!/usr/bin/env swift
/**
 Verifies Fixtures/stacks against Fixtures/expected.json using the real
 FrameworkDetector + ProjectScanner sources from the DevDock target.

 Usage (from repo root):
   ./scripts/generate-stack-fixtures.sh
   ./scripts/verify-stack-fixtures.swift
 */

import Foundation

let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .path

let stacksRoot = (repoRoot as NSString).appendingPathComponent("Fixtures/stacks")
let expectedPath = (repoRoot as NSString).appendingPathComponent("Fixtures/expected.json")
let sourcesDir = (repoRoot as NSString).appendingPathComponent("DevDock")

struct ExpectedFile: Decodable {
    struct Project: Decodable {
        let framework: String
        let port: Int?
    }
    let projects: [String: Project]
}

guard let expectedData = FileManager.default.contents(atPath: expectedPath),
      let expected = try? JSONDecoder().decode(ExpectedFile.self, from: expectedData) else {
    fputs("Failed to read \(expectedPath)\n", stderr)
    exit(1)
}

// Compile + run a tiny harness that links detector sources.
let work = FileManager.default.temporaryDirectory
    .appendingPathComponent("devdock-fixture-verify-\(UUID().uuidString)", isDirectory: true)
try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

let harness = work.appendingPathComponent("main.swift")
let harnessSource = """
import Foundation

let stacksRoot = CommandLine.arguments[1]
let expectedPath = CommandLine.arguments[2]

struct ExpectedFile: Decodable {
    struct Project: Decodable {
        let framework: String
        let port: Int?
    }
    let projects: [String: Project]
}

let expectedData = try Data(contentsOf: URL(fileURLWithPath: expectedPath))
let expected = try JSONDecoder().decode(ExpectedFile.self, from: expectedData)

var failures: [String] = []
var ok = 0

for (name, want) in expected.projects.sorted(by: { $0.key < $1.key }) {
    let path = (stacksRoot as NSString).appendingPathComponent(name)
    let detected = FrameworkDetector.detect(at: path)
    let port = FrameworkDetector.detectPort(at: path, framework: detected)
    if detected.rawValue != want.framework {
        failures.append("\\(name): framework want \\(want.framework) got \\(detected.rawValue)")
        continue
    }
    if want.port != port {
        failures.append("\\(name): port want \\(String(describing: want.port)) got \\(String(describing: port))")
        continue
    }
    ok += 1
    print("OK  \\(name) → \\(detected.rawValue)" + (port.map { " :\\($0)" } ?? ""))
}

let scanned = ProjectScanner().scan(roots: [stacksRoot])
let scannedNames = Set(scanned.map { URL(fileURLWithPath: $0.path).lastPathComponent })
let expectedNames = Set(expected.projects.keys)
let missingScan = expectedNames.subtracting(scannedNames).sorted()
let extraScan = scannedNames.subtracting(expectedNames).sorted()
if !missingScan.isEmpty {
    failures.append("scanner missed: \\(missingScan.joined(separator: ", "))")
}
if !extraScan.isEmpty {
    failures.append("scanner extra: \\(extraScan.joined(separator: ", "))")
}

print("---")
print("Detected OK: \\(ok)/\\(expected.projects.count)")
print("Scanner found: \\(scanned.count) projects")

if failures.isEmpty {
    print("ALL PASSED")
    exit(0)
}
fputs("FAILURES:\\n", stderr)
for f in failures {
    fputs("  - \\(f)\\n", stderr)
}
exit(1)
"""
try harnessSource.write(to: harness, atomically: true, encoding: .utf8)

let compileSources: [String] = [
    "Models/Framework.swift",
    "Models/DevProject.swift",
    "Services/FrameworkDetector.swift",
    "Services/ProjectScanner.swift",
    "Services/StartCommandResolver.swift",
    "Services/FlutterDevices.swift",
    "Services/Toolchain.swift",
    "Services/ScanRootLocator.swift",
].map { (sourcesDir as NSString).appendingPathComponent($0) }

let binary = work.appendingPathComponent("verify")
var args = ["-O", "-o", binary.path, harness.path] + compileSources

let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
proc.arguments = args
proc.currentDirectoryURL = work
let err = Pipe()
proc.standardError = err
proc.standardOutput = Pipe()
try proc.run()
proc.waitUntilExit()
if proc.terminationStatus != 0 {
    let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    fputs("swiftc failed:\n\(msg)\n", stderr)
    try? FileManager.default.removeItem(at: work)
    exit(1)
}

let run = Process()
run.executableURL = binary
run.arguments = [stacksRoot, expectedPath]
run.standardOutput = FileHandle.standardOutput
run.standardError = FileHandle.standardError
try run.run()
run.waitUntilExit()
try? FileManager.default.removeItem(at: work)
exit(run.terminationStatus)
