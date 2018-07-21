import Foundation

public class TinyCsvParser {

    private enum State {
        case startOfCell
        case insideUnquotedCell
        case insideQuotedCell
        case atAmbiguousQuote
    }

    private var rowNumber = 1
    private var columnNumber = 1

    private var state = State.startOfCell
    private var cellValue = ""
    private var cellValues = [String]()

    private var rowReadCallback: (([String]) -> Void)?
    private var rowByHeadersCallback: (([String: String]) -> Void)?
    private var fileReadCallback: (() -> Void)?
    private var didErrorCallback: ((Error) -> Void)?

    private var headers: [String]?

    public init() { }

    /// Sets the callback to be executed when a row has been read.
    public func didReadRowCellValues(on dispatchQueue: DispatchQueue = .main, action: @escaping (([String]) -> Void)) -> TinyCsvParser {
        rowReadCallback = dispatchQueue.asyncFunction(action: action)
        return self
    }

    public func didReadRowCellValuesByHeaders(on dispatchQueue: DispatchQueue = .main, action: @escaping (([String: String]) -> Void)) -> TinyCsvParser {
        rowByHeadersCallback = dispatchQueue.asyncFunction(action: action)
        return self
    }

    /// Sets the callback to be executed when the file has been fully read.
    public func didFinishFile(on dispatchQueue: DispatchQueue = .main, action: @escaping (() -> Void)) -> TinyCsvParser {
        fileReadCallback = { dispatchQueue.async(execute: action) }
        return self
    }

    /// Sets the callback to be executed when an error is found in the CSV file.
    public func didError(on dispatchQueue: DispatchQueue = .main, action: @escaping ((Error) -> Void)) -> TinyCsvParser {
        didErrorCallback = dispatchQueue.asyncFunction(action: action)
        return self
    }

    public func parseFile(at url: URL, qos: DispatchQoS.QoSClass = .userInteractive) {
        DispatchQueue.global(qos: qos).async {
            let fileReader: TextReader
            do {
                fileReader = try TextReader(filePath: url)

                repeat {
                    guard let character = try fileReader.readCharacter() else { break }
                    try self.processCharacter(character)
                } while true

                self.fileReadCallback?()
            } catch {
                self.didErrorCallback?(error)
            }
        }
    }

    private func processCharacter(_ character: Character) throws { //swiftlint:disable:this cyclomatic_complexity
        switch (state, character) {
        case (.startOfCell, "\""): state = .insideQuotedCell
        case (.startOfCell, ","): processCellEnd()
        case (.startOfCell, "\n"), (.startOfCell, "\r\n"): try processLineEnd()
        case (.startOfCell, _):
            state = .insideUnquotedCell
            cellValue.append(character)

        case (.insideUnquotedCell, "\""): throw CSVError.invalidCsv
        case (.insideUnquotedCell, ","): processCellEnd()
        case (.insideUnquotedCell, "\n"), (.insideUnquotedCell, "\r\n"): try processLineEnd()
        case (.insideUnquotedCell, _): cellValue.append(character)

        case (.insideQuotedCell, "\""): state = .atAmbiguousQuote
        case (.insideQuotedCell, _): cellValue.append(character)

        case (.atAmbiguousQuote, ","): processCellEnd()
        case (.atAmbiguousQuote, "\n"), (.atAmbiguousQuote, "\r\n"): try processLineEnd()
        case (.atAmbiguousQuote, "\""):
            state = .insideQuotedCell
            cellValue.append("\"")
        case (.atAmbiguousQuote, _): throw CSVError.invalidCsv
        }
    }

    private func processCellEnd() {
        cellValues.append(cellValue)
        cellValue.removeAll()
        state = .startOfCell
        columnNumber += 1
    }

    private func processLineEnd() throws {
        processCellEnd()
        columnNumber = 0

        if let rowByHeadersCallback = rowByHeadersCallback {
            if rowNumber == 1 {
                headers = cellValues
            } else {
                guard cellValues.count == headers!.count else { throw CSVError.invalidCsv }
                rowByHeadersCallback(headers!.enumerated().reduce(into: [String: String]()) { dict, cell in
                    dict[cell.element] = cellValues[cell.offset]
                })
            }
        } else {
            rowReadCallback?(cellValues)
        }
        cellValues.removeAll()
        rowNumber += 1
    }
}

public enum CSVError: Error {
    case invalidCsv
}

public class TextReader {
    private let encoding: String.Encoding
    private var characterBuffer = [Character]()
    private var dataBuffer = Data(capacity: 4)

    private let fileHandle: FileHandle

    private var currentBufferIndex = -1
    private var hasCompletedFile = false

    private let fileReadBatchSize = 4096

    public init(filePath: URL, encoding: String.Encoding? = nil) throws {
        self.fileHandle = try FileHandle(forReadingFrom: filePath)
        if let encoding = encoding {
            self.encoding = encoding
        } else {
            let bytes = fileHandle.readData(ofLength: 4)
            let determinedEncoding = TextReader.determineEncoding(bytes)
            self.encoding = determinedEncoding.encoding ?? .utf8
            self.dataBuffer.append(bytes[determinedEncoding.byteOrderMarkSize...])
        }
    }

    deinit {
        self.fileHandle.closeFile()
    }

    /**
     Returns the encoding and the size of the byte order mark which indicated this encoding. The recognised
     options are UTF-32 (BE and LE), UTF-16 (BE and LE), and UTF-8. A nil encoding (which will be accompanied
     with a byte order mark size of 0) means the encoding was not recognised.
     */
    public static func determineEncoding(_ data: Data) -> (encoding: String.Encoding?, byteOrderMarkSize: Int) {
        if data.count >= 4 && data[0] == 0x00 && data[1] == 0x00 && data[2] == 0xFE && data[3] == 0xFF {
            return (.utf32BigEndian, 4)
        } else if data.count >= 4 && data[0] == 0xFF && data[1] == 0xFE && data[2] == 0x00 && data[3] == 0x00 {
            return (.utf32LittleEndian, 4)
        } else if data.count >= 2 && data[0] == 0xFE && data[1] == 0xFF {
            return (.utf16BigEndian, 2)
        } else if data.count >= 2 && data[0] == 0xFF && data[1] == 0xFE {
            return (.utf32LittleEndian, 2)
        } else if data.count >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF {
            return (.utf8, 3)
        } else {
            return (nil, 0)
        }
    }

    public func readCharacter() throws -> Character? {
        try advance()
        guard !hasCompletedFile else { return nil }
        return characterBuffer[currentBufferIndex]
    }

    private func advance() throws {
        if currentBufferIndex < characterBuffer.endIndex - 1 {
            currentBufferIndex += 1
        } else {
            try reloadBuffers()
        }
    }

    private func reloadBuffers() throws {
        // Get new data from the file
        let newData = fileHandle.readData(ofLength: fileReadBatchSize)
        guard !newData.isEmpty else { hasCompletedFile = true; return }

        // Create a sequence of data which consists of the data buffer plus the newly read data
        var data = Data(dataBuffer)
        data.append(newData)
        dataBuffer.removeAll()

        // Try to decode it. This may fail, if the data ends in an awkward place
        var decodedData = String(bytes: data, encoding: encoding)

        // If we couldn't decode the data, remove and save the last byte and try again
        var decodeRetryCount = 0
        while decodedData == nil && decodeRetryCount <= 3 {
            let byte = data.removeLast()
            dataBuffer.append(byte)
            decodedData = String(bytes: data, encoding: encoding)
            decodeRetryCount += 1
        }

        if let decodedData = decodedData {
            characterBuffer = Array(decodedData)
            currentBufferIndex = 0
        } else {
            throw TextReaderError.couldNotDecodeFile
        }
    }
}

public enum TextReaderError: Error {
    case couldNotDecodeFile
}

extension DispatchQueue {
    /// Returns a function which schedules the provided function to run asynchronously on this dispatch queue.
    func asyncFunction<T>(action: @escaping ((T) -> Void)) -> ((T) -> Void) {
        return { value in
            self.async {
                action(value)
            }
        }
    }
}
