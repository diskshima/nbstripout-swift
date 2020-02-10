import Foundation

import ArgumentParserKit
import SwiftyJSON

enum NBConstants {
    public static let metadata: JSONSubscriptType = "metadata"
    public static let cells: JSONSubscriptType = "cells"
}

func cleanMetadata(_ json: inout JSON) {
    // TODO: Support exclude list.
    json[NBConstants.metadata] = JSON([String: Any?]())
}

func parseArguments() -> (filepath: String, textconv: Bool)? {
    let filepath: String
    let textconv: Bool

    do {
        let parser = ArgumentParser(commandName: "nbstripout-swift",
                                    usage: "[-t] filepath",
                                    overview: "Strip out non-source cells and metadata from Jupyter notebooks")

        let ptextconv = parser.add(option: "--textconv",
                                   shortName: "-t",
                                   kind: Bool.self,
                                   usage: "Prints out the result to standard output instead of overwriting the file.",
                                   completion: ShellCompletion.none)

        let pfilepath = parser.add(positional: "filepath",
                                   kind: String.self,
                                   optional: false,
                                   usage: "File path to Jupyter notebook.",
                                   completion: ShellCompletion.filename)

        let argsv = Array(CommandLine.arguments.dropFirst())
        let pargs = try parser.parse(argsv)

        textconv = pargs.get(ptextconv) ?? false
        filepath = pargs.get(pfilepath)!
        return (filepath: filepath, textconv: textconv)
    } catch ArgumentParserError.expectedValue(let value) {
        print("Missing value for argument \(value).")
    } catch ArgumentParserError.expectedArguments(_, let stringArray) {
        print("Missing arguments: \(stringArray.joined())")
    } catch {
        print(error.localizedDescription)
    }

    return nil
}

func cleanCells(_ json: inout JSON) {
    let cells = json[NBConstants.cells]
    var newCells: [JSON] = []

    for cell in cells.arrayValue {
        var newDict = JSON([String: Any?]())
        for (key, subJson): (String, JSON) in cell {
            var newValue: JSON
            switch key {
            case "metadata":
                // TODO: Support exclude list.
                newValue = JSON([String: Any?]())
            case "outputs":
                newValue = JSON([])
            case "execution_count":
                newValue = JSON.null
            default:
                newValue = subJson
            }

            newDict[key] = newValue
        }

        newCells.append(newDict)
    }

    json[NBConstants.cells] = JSON(newCells)
}

func cleanNotebook(_ json: inout JSON) {
    cleanMetadata(&json)
    cleanCells(&json)
}

func main() {
    guard let args = parseArguments() else { exit(-1) }

    let data: Data
    do {
        let content = try String(contentsOfFile: args.filepath, encoding: .utf8)
        data = content.data(using: .utf8, allowLossyConversion: false)!
    } catch {
        print("Failed to read file.")
        return
    }

    guard var json = try? JSON(data: data) else {
        print("Failed to convert data to JSON.")
        return
    }

    cleanNotebook(&json)

    guard let jsonStr = json.rawString() else {
        print("Failed to convert JSON to String.")
        exit(-1)
    }

    if args.textconv {
        print(jsonStr)
    } else {
        do {
            try jsonStr.write(toFile: args.filepath, atomically: false, encoding: .utf8)
        } catch {
            print("Failed to write to file.")
            exit(-1)
        }
    }
}

main()
