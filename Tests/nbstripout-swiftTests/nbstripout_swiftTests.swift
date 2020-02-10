import XCTest
import class Foundation.Bundle

final class nbstripout_swiftTests: XCTestCase {
    let sampleNB = URL(fileURLWithPath: "Tests/examples/fizzbuzz_colab.ipynb")

    func genTempFile() -> URL {
        let tempDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let filename = NSUUID().uuidString
        return URL(fileURLWithPath: filename, relativeTo: tempDirURL)
    }

    func createTemporaryNB() -> URL {
        let tempfile = genTempFile()
        guard (try? FileManager.default.copyItem(at: sampleNB, to: tempfile)) != nil else {
            fatalError("Failed to create a temporary copy of the sample notebook.")
        }
        return tempfile
    }

    func executeBinary(arguments: [String]? = []) -> String? {
        let binary = productsDirectory.appendingPathComponent("nbstripout-swift")

        let process = Process()
        process.executableURL = binary
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe

        guard (try? process.run()) != nil else {
            XCTFail("Failed to execute process.")
            return nil
        }

        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        return String(data: data, encoding: .utf8)
    }

    func testWhenNoFilepathsAreGiven() throws {
        let output = executeBinary()
        XCTAssertEqual(output, "Missing arguments: filepaths\n")
    }

    func testWhenInvalidFilepathIsGiven() throws {
        let output = executeBinary(
            arguments: "INVALID_FILE_PATH".components(separatedBy: " "))

        XCTAssertEqual(output, "Failed to read file.\n")
    }

    func testTOptionShouldNotUpdateOriginalFile() throws {
        let tempfile = createTemporaryNB()
        let contentBefore = try String(contentsOf: tempfile, encoding: .utf8)
        _ = executeBinary(
            arguments: "-t -c \(tempfile.path)".components(separatedBy: " "))
        let contentAfter = try String(contentsOf: tempfile, encoding: .utf8)

        XCTAssertEqual(contentAfter, contentBefore)
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
