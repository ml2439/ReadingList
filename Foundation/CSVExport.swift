import Foundation

class CsvColumn<TData> {
    let header: String
    let cellValue: (TData) -> String?
    
    init(header: String, cellValue: @escaping (TData) -> String?) {
        self.header = header
        self.cellValue = cellValue
    }
}

class CsvExport<TData> {
    let columns: [CsvColumn<TData>]
    
    init(columns: [CsvColumn<TData>]) {
        self.columns = columns
    }
    
    func headers() -> [String] {
        return columns.map{$0.header}
    }
    
    func cellValues(data: TData) -> [String] {
        return columns.map{$0.cellValue(data) ?? ""}
    }
}

class CsvExporter<TData> {
    let csvExport: CsvExport<TData>
    private var document: String
    
    init(csvExport: CsvExport<TData>){
        self.csvExport = csvExport
        document = CsvExporter.convertToCsvLine(csvExport.headers())
    }
    
    func addData(_ data: TData) {
        document.append(CsvExporter.convertToCsvLine(csvExport.cellValues(data: data)))
    }
    
    func addData(_ dataArray: [TData]) {
        for data in dataArray {
            addData(data)
        }
    }
    
    private static func convertToCsvLine(_ cellValues: [String]) -> String {
        return cellValues.map{ cellValue in
            let charactersWhichRequireWrapping = CharacterSet(charactersIn: "\n,")
            let wrapInQuotes = cellValue.rangeOfCharacter(from: charactersWhichRequireWrapping) != nil
            
            // Replace " with ""
            let escapedString = cellValue.replacingOccurrences(of: "\"", with: "\"\"")
            
            if wrapInQuotes {
                return "\"\(escapedString)\""
            }
            return escapedString
        }.joined(separator: ",") + "\n"
    }
    
    func write(to fileURL: URL) throws {
        try document.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
