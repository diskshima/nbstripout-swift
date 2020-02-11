import Foundation

import ArgumentParserKit
import SwiftyJSON

enum NBConstants {
    public static let metadata = "metadata"
    public static let cells = "cells"
    public static let kernelspec = "kernelspec"
    public static let accelerator = "accelerator"
    public static let colab = "colab"
}

struct RemoveOptions: OptionSet {
    let rawValue: Int

    static let outputs = RemoveOptions(rawValue: 1 << 0)
    static let executionCount = RemoveOptions(rawValue: 1 << 1)
    static let colab = RemoveOptions(rawValue: 1 << 2)

    static let none: RemoveOptions = []
    static let all: RemoveOptions = [.outputs, .executionCount, .colab]
}

struct CmdOptions {
    let filepaths: [String]
    let textconv: Bool
    let removeOptions: RemoveOptions
}

func parseArguments() -> CmdOptions? {
    do {
        let parser = ArgumentParser(commandName: "nbstripout",
                                    usage: "[-ceot] file1 file2...",
                                    overview: "Strip out non-source cells and metadata from Jupyter notebooks")

        let ptextconv = parser.add(option: "--textconv",
                                   shortName: "-t",
                                   kind: Bool.self,
                                   usage: "Prints out the result to standard output instead of overwriting the file.",
                                   completion: ShellCompletion.none)

        let poutputs = parser.add(option: "--outputs",
                                  shortName: "-o",
                                  kind: Bool.self,
                                  usage: "Remove outputs fields.",
                                  completion: ShellCompletion.none)

        let pexecCount = parser.add(option: "--execution-count",
                                    shortName: "-e",
                                    kind: Bool.self,
                                    usage: "Remove execution count fields.",
                                    completion: ShellCompletion.none)

        let pcolab = parser.add(option: "--colab",
                                shortName: "-c",
                                kind: Bool.self,
                                usage: "Remove colab related fields.",
                                completion: ShellCompletion.none)

        let pfilepaths = parser.add(positional: "filepaths",
                                kind: [String].self,
                                optional: true,
                                strategy: .upToNextOption,
                                usage: "File paths to Jupyter notebooks.",
                                completion: ShellCompletion.filename)

        let argsv = Array(CommandLine.arguments.dropFirst())
        let pargs = try parser.parse(argsv)

        let filepaths = pargs.get(pfilepaths) ?? []
        let textconv = pargs.get(ptextconv) ?? false

        var removeOptions = RemoveOptions.none

        if pargs.get(poutputs) ?? false { removeOptions.insert(.outputs) }
        if pargs.get(pexecCount) ?? false { removeOptions.insert(.executionCount) }
        if pargs.get(pcolab) ?? false { removeOptions.insert(.colab) }

        // If nothing was specified, default to clean all.
        if removeOptions.isEmpty { removeOptions = RemoveOptions.all }

        return CmdOptions(
            filepaths: filepaths, textconv: textconv, removeOptions: removeOptions
        )
    } catch ArgumentParserError.expectedValue(let value) {
        print("Missing value for argument \(value).")
    } catch ArgumentParserError.expectedArguments(_, let stringArray) {
        print("Missing arguments: \(stringArray.joined())")
    } catch {
        print(error.localizedDescription)
    }

    return nil
}

func readAllInput() -> Data {
    var data = Data()
    let standardInput = FileHandle.standardInput
    while true {
        let input = standardInput.availableData
        if input.count == 0 { break }
        data.append(input)
    }
    return data
}

func cleanMetadata(_ json: inout JSON, _ removeOptions: RemoveOptions) {
    let metadata = json[NBConstants.metadata]

    var newMetadata = JSON([String: Any?]())

    var keeps = [NBConstants.kernelspec]

    if removeOptions.contains(.colab) == false {
        keeps.append(contentsOf: [NBConstants.accelerator, NBConstants.colab])
    }

    keeps.forEach { newMetadata[$0] = metadata[$0] }

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

func processData(_ data: Data, _ removeOptions: RemoveOptions) -> String {
    guard var json = try? JSON(data: data) else {
        print("Failed to convert data to JSON.")
        exit(-1)
    }

    cleanNotebook(&json, removeOptions)

    guard let jsonStr = json.rawString() else {
        print("Failed to convert JSON to String.")
        exit(-1)
    }

    return jsonStr
}

func processFile(_ file: URL, _ cmdOptions: CmdOptions) {
    let content: Data
    do {
        content = try Data(contentsOf: file)
    } catch {
        print("Failed to read file.")
        return
    }

    let jsonStr = processData(content, cmdOptions.removeOptions)

    if cmdOptions.textconv {
        print(jsonStr)
    } else {
        do {
            try jsonStr.write(to: file, atomically: false, encoding: .utf8)
        } catch {
            print("Failed to write to file.")
            exit(-1)
        }
    }
}

func main() {
    guard let cmdOptions = parseArguments() else { exit(-1) }

    if cmdOptions.filepaths.count == 0 {
        let stdinData = readAllInput()
        let jsonStr = processData(stdinData, cmdOptions.removeOptions)
        print(jsonStr)
    } else {
        for filepath in cmdOptions.filepaths {
            processFile(URL(fileURLWithPath: filepath), cmdOptions)
        }
    }
}

main()
