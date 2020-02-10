# nbstripout-swift

[nbstripout](https://github.com/kynan/nbstripout) implementation in Swift.

## Usage

```bash
OVERVIEW: Strip out non-source cells and metadata from Jupyter notebooks

USAGE: nbstripout-swift [-ceot] file1 file2...

OPTIONS:
  --colab, -c             Remove colab related fields.
  --execution-count, -e   Remove execution count fields.
  --outputs, -o           Remove outputs fields.
  --textconv, -t          Prints out the result to standard output instead of overwriting the file.
  --help                  Display available options

POSITIONAL ARGUMENTS:
  filepaths               File paths to Jupyter notebooks.
```

## Building

```bash
swift build
```

## Running Tests

```bash
swift test
```
