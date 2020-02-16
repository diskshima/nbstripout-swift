import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(nbstripout_tests.allTests)
    ]
}
#endif
