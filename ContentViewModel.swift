import SwiftUI
import Combine
import Foundation

struct CellContent: Identifiable, Equatable {
    let id: UUID
    var operatorSymbol: String
    var text: String
    var color: Color
    
    init(id: UUID = UUID(), operatorSymbol: String, text: String, color: Color) {
        self.id = id
        self.operatorSymbol = operatorSymbol
        self.text = text
        self.color = color
    }
    
    static func == (lhs: CellContent, rhs: CellContent) -> Bool {
        lhs.id == rhs.id &&
        lhs.operatorSymbol == rhs.operatorSymbol &&
        lhs.text == rhs.text
    }
}

class ContentViewModel: ObservableObject {
    @Published var cellContents: [CellContent] = []
    @Published var currentInput: String = "0" {
        didSet {
            displayInput = currentInput.isEmpty ? "0" : currentInput
        }
    }
    @Published var showACTooltip: Bool {
        didSet {
            UserDefaults.standard.set(showACTooltip, forKey: "showACTooltip")
        }
    }
    @Published var displayInput: String = "0"
    @Published var currentOperator: String?
    @Published var previousInput: Decimal?
    @Published var displayOperator: String = ""
    @Published var isNewInput: Bool = true
    @Published var isEqualJustPressed: Bool = false
    @Published var lastResult: Decimal?
    @Published var scrollViewHeight: CGFloat = 0

    public let inputDisplayHeight: CGFloat = 66 //数字専用ディスプレイの高さ
    public let adBannerHeight: CGFloat = 50 //　広告表示枠の高さ
    public let cellHeight: CGFloat = 41 // テーブルセルの高さ

    private let calculator = DecimalCalculator.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // UserDefaultsから状態を読み込む
        self.showACTooltip = UserDefaults.standard.bool(forKey: "showACTooltip")
        
        // もし値が保存されていなかった場合（初回起動時）、デフォルトでtrueに設定
        if !UserDefaults.standard.contains(key: "showACTooltip") {
            self.showACTooltip = true
        }
        // scrollViewHeightの変更を監視
        $scrollViewHeight
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] newHeight in
                self?.handleScrollViewHeightChange(newHeight)
            }
            .store(in: &cancellables)
    }
    
    func disableACTooltip() {
        showACTooltip = false
        UserDefaults.standard.set(false, forKey: "showACTooltip")
    }
    
    //scrollViewHeithが変更となったときに呼び出され、配列を提供する
    //handleScrollViewHeightChange
    private func handleScrollViewHeightChange(_ newHeight: CGFloat) {
        let newRowCount = Int(newHeight / cellHeight) + 2
        if newRowCount != cellContents.count {
            allClear()
        }
        // 必要に応じて他の処理を追加
    }
    
    private func initializeCellContents(rowCount: Int) {
        cellContents = (0..<rowCount).map { _ in
            CellContent(operatorSymbol: "", text: " ", color: .black)
        }
    }

    // スクロールビューが表示されたときに呼び出されてscrollViewHeightを提供する
    func updateScrollViewHeight(_ newHeight: CGFloat) {
        scrollViewHeight = newHeight
    }

    private func performOperation(_ a: Decimal, _ b: Decimal, _ op: String) {
        switch op {
        case "+": calculator.add(a, b)
        case "-": calculator.subtract(a, b)
        case "×": calculator.multiply(a, b)
        case "÷": calculator.divide(a, b)
        default: break
        }
    }

    func clearCurrentInput() {
        if displayOperator == "=" {
            displayOperator = ""
            displayInput = "0"
            currentInput = "0"
            currentOperator = nil
            previousInput = nil
            isNewInput = true
            isEqualJustPressed = false
            lastResult = nil
            // cellContentsはそのまま保持
        } else {
            currentInput = "0"
            isNewInput = true
        }
    }

    func allClear() {
        currentInput = "0"
        currentOperator = nil
        previousInput = nil
        displayOperator = ""
        displayInput = "0"
        calculator.result = 0
        isNewInput = true
        isEqualJustPressed = false
        cellContents.removeAll()
        initializeCellContents(rowCount: Int(scrollViewHeight / cellHeight) + 2)
        objectWillChange.send()
    }

    func addDigit(_ digit: String) {
        if isEqualJustPressed {
            resetCalculation()
        }
        if isNewInput {
            currentInput = ""
            isNewInput = false
        }
        switch digit {
        case ".":
            if !currentInput.contains(".") {
                currentInput += currentInput.isEmpty ? "0." : "."
            }
        case "00":
            currentInput = currentInput == "0" || currentInput.isEmpty ? "0" : currentInput + "00"
        default:
            currentInput = currentInput == "0" ? digit : currentInput + digit
        }
    }

    func addCell(operatorSymbol: String, text: String, color: Color) {
        if let firstCell = cellContents.first, firstCell.text == " " {
            // 配列をシフトする
            for i in 0..<(cellContents.count - 1) {
                cellContents[i] =  cellContents[i + 1]
            }
            // 最後のセルに上書きをする
            cellContents[cellContents.count - 1] = CellContent(operatorSymbol: operatorSymbol, text: text, color: color)

        } else {
            // 新しいセルを追加する
            cellContents.append(CellContent(operatorSymbol: operatorSymbol, text: text, color: color))
        }
        objectWillChange.send()
    }
    
    func setOperator(_ op: String) {
        // allClearの状態（previousInputがnilで、currentInputが"0"）では演算子を無視
        if previousInput == nil && currentInput == "0" {
            return
        }
        if isEqualJustPressed {
            previousInput = lastResult
            lastResult = nil
            addCell(operatorSymbol: "", text: calculator.formatResult(), color: .blue)
        } else if isNewInput && currentOperator != nil {
            // 演算子が連続して押された場合、演算子を入れ替える
            currentOperator = op
            displayOperator = op
            // 最後のセルの演算子を更新
            if let lastIndex = cellContents.lastIndex(where: { !$0.operatorSymbol.isEmpty }) {
                cellContents[lastIndex].operatorSymbol = op
            }
            return
        } else if let previous = previousInput, let current = Decimal(string: currentInput), !currentInput.isEmpty && currentInput != "0" {
            performOperation(previous, current, currentOperator ?? "")
            addCell(operatorSymbol: currentOperator ?? "", text: currentInput, color: .gray)
            previousInput = calculator.result
            displayInput = calculator.formatResult()

        } else if previousInput == nil {
            previousInput = Decimal(string: currentInput)
            addCell(operatorSymbol: "", text: currentInput, color: .gray)
        }
        currentOperator = op
        displayOperator = op
        isNewInput = true
        isEqualJustPressed = false
    }

    func calculate() {
        guard let op = currentOperator, let previous = previousInput, let current = Decimal(string: currentInput) else {
            return
        }

        performOperation(previous, current, op)
        let result = calculator.formatResult()

        addCell(operatorSymbol: op, text: currentInput, color: .gray)
        addCell(operatorSymbol: "=", text: result, color: .blue)

        // 空白行を追加
        addCell(operatorSymbol: "", text: "", color: .clear)

        
        displayOperator = "="
        displayInput = result
        lastResult = calculator.result
        isEqualJustPressed = true
        isNewInput = true

        previousInput = nil
        currentOperator = nil
    }

    private func resetCalculation() {
        currentInput = ""
        displayOperator = "" // ここでも演算子表示をクリア
        displayInput = "0"
        currentOperator = nil
        previousInput = nil
        lastResult = nil
        isEqualJustPressed = false
        isNewInput = true
    }
    
    func toggleSign() {
        if currentInput != "0" {
            if currentInput.hasPrefix("-") {
                currentInput.removeFirst()
            } else {
                currentInput = "-" + currentInput
            }
        }
    }
}
// UserDefaults拡張
extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
