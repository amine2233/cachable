import XCTest

import cachableTests

var tests = [XCTestCaseEntry]()
tests += cachableTests.allTests()
XCTMain(tests)
