import XCTest
import class Foundation.Bundle

import SwiftyJSON

final class nbstripout_swiftTests: XCTestCase {
    static let sampleNB = URL(fileURLWithPath: "Tests/examples/fizzbuzz_colab.ipynb")
    static let sampleNB2 = URL(fileURLWithPath: "Tests/examples/fibonacci_colab.ipynb")

    func genTempFile() -> URL {
        let tempDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let filename = NSUUID().uuidString
        return URL(fileURLWithPath: filename, relativeTo: tempDirURL)
    }

    func createTemporaryNB(_ notebook: URL = sampleNB) -> URL {
        let tempfile = genTempFile()
        guard (try? FileManager.default.copyItem(at: notebook, to: tempfile)) != nil else {
            fatalError("Failed to create a temporary copy of the sample notebook.")
        }
        return tempfile
    }

    func readJSON(_ file: URL) -> JSON {
        guard let content = try? String(contentsOf: file, encoding: .utf8) else {
            fatalError("Failed to read temprary file.")
        }
        let data = content.data(using: .utf8, allowLossyConversion: false)!

        guard let json = try? JSON(data: data) else {
            fatalError("Failed to parse JSON.")
        }

        return json
    }

    func executeBinary(arguments: String? = nil) -> String? {
        let binary = productsDirectory.appendingPathComponent("nbstripout-swift")

        let process = Process()
        process.executableURL = binary

        if arguments != nil {
            process.arguments = arguments?.components(separatedBy: " ")
        }

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
        let output = executeBinary(arguments: "INVALID_FILE_PATH")

        XCTAssertEqual(output, "Failed to read file.\n")
    }

    func testCOptionShouldOnlyRemoveColab() throws {
        let tempfile = createTemporaryNB()

        _ = executeBinary(arguments: "-c \(tempfile.path)")

        let json = readJSON(tempfile)

        XCTAssertEqual(json["metadata"]["accelerator"].description, "null")
        XCTAssertEqual(json["metadata"]["colab"].description, "null")

        let cells = json["cells"]
        cells.arrayValue.forEach { cell in
            XCTAssertNotEqual(cell["execution_count"].description, "null")
        }
    }

    func testEOptionShouldOnlyRemoveExecutionCount() throws {
        let tempfile = createTemporaryNB()

        _ = executeBinary(arguments: "-e \(tempfile.path)")

        let json = readJSON(tempfile)

        let cells = json["cells"]
        cells.arrayValue.forEach { cell in
            XCTAssertEqual(cell["execution_count"].description, "null")
        }

        XCTAssertNotEqual(json["metadata"]["accelerator"].description, "null")
        XCTAssertNotEqual(json["metadata"]["colab"].description, "null")
    }

    func testOOptionShouldOnlyRemoveOutputs() throws {
        let tempfile = createTemporaryNB()

        _ = executeBinary(arguments: "-o \(tempfile.path)")

        let json = readJSON(tempfile)

        let cells = json["cells"]
        cells.arrayValue.forEach { cell in
            XCTAssertEqual(cell["outputs"], JSON([]))
            XCTAssertNotEqual(cell["execution_count"].description, "null")
        }

        XCTAssertNotEqual(json["metadata"]["accelerator"].description, "null")
        XCTAssertNotEqual(json["metadata"]["colab"].description, "null")
    }

    func testNoOptionsShouldRemoveAll() throws {
        let tempfile = createTemporaryNB()

        _ = executeBinary(arguments: tempfile.path)

        let json = readJSON(tempfile)

        XCTAssertEqual(json["metadata"]["accelerator"].description, "null")
        XCTAssertEqual(json["metadata"]["colab"].description, "null")

        let cells = json["cells"]
        cells.arrayValue.forEach { cell in
            XCTAssertEqual(cell["outputs"], JSON([]))
            XCTAssertEqual(cell["execution_count"].description, "null")
        }
    }

    func testTOptionShouldNotUpdateOriginalFile() throws {
        let tempfile = createTemporaryNB()
        let contentBefore = try String(contentsOf: tempfile, encoding: .utf8)

        _ = executeBinary(arguments: "-t \(tempfile.path)")

        let contentAfter = try String(contentsOf: tempfile, encoding: .utf8)

        XCTAssertEqual(contentAfter, contentBefore)
    }

    func testShouldProcessMultipleFiles() throws {
        let tempfile = createTemporaryNB()
        let tempfile2 = createTemporaryNB(nbstripout_swiftTests.sampleNB2)

        _ = executeBinary(arguments: "\(tempfile.path) \(tempfile2.path)")

        [tempfile, tempfile2].forEach { file in
            let json = readJSON(file)
            XCTAssertEqual(json["metadata"]["accelerator"].description, "null")
            XCTAssertEqual(json["metadata"]["colab"].description, "null")

            let cells = json["cells"]
            cells.arrayValue.forEach { cell in
                XCTAssertEqual(cell["outputs"], JSON([]))
                XCTAssertEqual(cell["execution_count"].description, "null")
            }
        }
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
