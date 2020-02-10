import XCTest
import class Foundation.Bundle

final class nbstripout_swiftTests: XCTestCase {
    func executeBinary() throws -> String? {
        let binary = productsDirectory.appendingPathComponent("nbstripout-swift")

        let process = Process()
        process.executableURL = binary

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        return String(data: data, encoding: .utf8)
    }

    func testWhenNoFilepathsAreGiven() throws {
        let output = try! executeBinary()

        XCTAssertEqual(output, "Missing arguments: filepaths\n")
    }

    /// Returns path to the built products directory.
    var productsDirectory: URL {
      #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
      #else
        return Bundle.main.bundleURL
      #endif
    }

    static var allTests = [
        ("testWhenNoFilepathsAreGiven", testWhenNoFilepathsAreGiven)
    ]
}
