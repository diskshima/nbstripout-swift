import Foundation

import ArgumentParserKit
import SwiftyJSON

enum NBConstants {
    public static let metadata: JSONSubscriptType = "metadata"
    public static let cells: JSONSubscriptType = "cells"
    public static let kernelspec: JSONSubscriptType = "kernelspec"
}

struct RemoveOptions: OptionSet {
    let rawValue: Int

    static let outputs = RemoveOptions(rawValue: 1 << 0)
    static let executionCount = RemoveOptions(rawValue: 1 << 1)
    static let colab = RemoveOptions(rawValue: 1 << 2)

    static let none: RemoveOptions = []
    static let all: RemoveOptions = [.outputs, .executionCount, .colab]
}

struct Options {
    let filepaths: [String]
    let textconv: Bool
    let removeOptions: RemoveOptions
}

func parseArguments() -> Options? {
    do {
        let parser = ArgumentParser(commandName: "nbstripout-swift",
                                    usage: "[-t] [-o] file1 file2...",
                                    overview: "Strip out non-source cells and metadata from Jupyter notebooks")

        let ptextconv = parser.add(option: "--textconv",
                                   shortName: "-t",
                                   kind: Bool.self,
                                   usage: "Prints out the result to standard output instead of overwriting the file.",
                                   completion: ShellCompletion.none)

        let poutputs = parser.add(option: "--outputs",
                                  shortName: "-o",
                                  kind: Bool.self,
                                  usage: "Remove outputs.",
                                  completion: ShellCompletion.none)

        let pexecCount = parser.add(option: "--execution-counts",
                                    shortName: "-e",
                                    kind: Bool.self,
                                    usage: "Remove execution counts.",
                                    completion: ShellCompletion.none)

        let pfilepaths = parser.add(positional: "filepaths",
                                    kind: [String].self,
                                    optional: false,
                                    strategy: .upToNextOption,
                                    usage: "File paths to Jupyter notebook.",
                                    completion: ShellCompletion.filename)

        let argsv = Array(CommandLine.arguments.dropFirst())
        let pargs = try parser.parse(argsv)

        let filepaths = pargs.get(pfilepaths)!
        let textconv = pargs.get(ptextconv) ?? false

        // Options
        var removeOptions = RemoveOptions.none

        if pargs.get(poutputs) ?? false {
            removeOptions.insert(.outputs)
        }

        if pargs.get(pexecCount) ?? false {
            removeOptions.insert(.executionCount)
        }

        // If nothing was specified, default to clean all.
        if removeOptions.isEmpty {
            removeOptions = RemoveOptions.all
        }

        return Options(filepaths: filepaths,
                       textconv: textconv,
                       removeOptions: removeOptions)
    } catch ArgumentParserError.expectedValue(let value) {
        print("Missing value for argument \(value).")
    } catch ArgumentParserError.expectedArguments(_, let stringArray) {
        print("Missing arguments: \(stringArray.joined())")
    } catch {
        print(error.localizedDescription)
    }

    return nil
}

func cleanMetadata(_ json: inout JSON, _ removeOptions: RemoveOptions) {
    // TODO: Support exclude list.
    let metadata = json[NBConstants.metadata]

    var newMetadata = JSON([String: Any?]())

    newMetadata[NBConstants.kernelspec] = metadata[NBConstants.kernelspec]

    json[NBConstants.metadata] = newMetadata
}

func cleanCells(_ json: inout JSON, _ removeOptions: RemoveOptions) {
    let cells = json[NBConstants.cells]
    var newCells: [JSON] = []

    for cell in cells.arrayValue {
        var newDict = JSON([String: Any?]())
        for (key, subJson): (String, JSON) in cell {
            var newValue: JSON = subJson
            switch key {
            case "metadata":
                newValue = JSON([String: Any?]())
            case "outputs":
                if removeOptions.contains(.outputs) {
                    newValue = JSON([])
                }
            case "execution_count":
                if removeOptions.contains(.executionCount) {
                    newValue = JSON.null
                }
            default:
                newValue = subJson
            }

            newDict[key] = newValue
        }

        newCells.append(newDict)
    }

    json[NBConstants.cells] = JSON(newCells)
}

func cleanNotebook(_ json: inout JSON, _ removeOptions: RemoveOptions) {
    cleanMetadata(&json, removeOptions)
    cleanCells(&json, removeOptions)
}

func processFile(_ filepath: String, _ options: Options) {
    let data: Data
    do {
        let content = try String(contentsOfFile: filepath, encoding: .utf8)
        data = content.data(using: .utf8, allowLossyConversion: false)!
    } catch {
        print("Failed to read file.")
        return
    }

    guard var json = try? JSON(data: data) else {
        print("Failed to convert data to JSON.")
        return
    }

    cleanNotebook(&json, options.removeOptions)

    guard let jsonStr = json.rawString() else {
        print("Failed to convert JSON to String.")
        exit(-1)
    }

    if options.textconv {
        print(jsonStr)
    } else {
        do {
            try jsonStr.write(toFile: filepath, atomically: false, encoding: .utf8)
        } catch {
            print("Failed to write to file.")
            exit(-1)
        }
    }
}

func main() {
    guard let options = parseArguments() else { exit(-1) }

    for filepath in options.filepaths {
        processFile(filepath, options)
    }
}

main()
