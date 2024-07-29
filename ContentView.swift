import SwiftUI
import AppTrackingTransparency

struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var isATTAuthorized: Bool
    @State private var viewSize: CGSize = .zero
    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var lastContentId: UUID?
    @State private var scrollViewOffset: CGFloat = 0
    @State private var isTooltipVisible: Bool = false
    public let inputDisplayHeight: CGFloat = 66 //数字専用ディスプレイの高さ
    public let adBannerHeight: CGFloat = 50 //広告表示枠の高さ
    
    var body: some View {
        GeometryReader{bodygeometry in
            let screenHeight = bodygeometry.size.height
            let minScrollViewHeight: CGFloat = 100
            let calculatedScrollViewHeight = max(minScrollViewHeight, screenHeight - (adBannerHeight + inputDisplayHeight + keypadHeight)) //- 8
            let calcWidth = isPadAndNotCatalyst ? bodygeometry.size.width * 0.6 : bodygeometry.size.width
            HStack(spacing:0){
                if isPadAndNotCatalyst {Spacer()}
                ZStack {
                    //===================================Z1
                    // upper parts (or left parts)
                    //===================================Z1
                    VStack(spacing:0){
                        HStack(spacing: 0) {
                            grayBarView() // side bar
                            ScrollViewContent()
                            grayBarView()   //side bar
                        }
                        .edgesIgnoringSafeArea(.top)
                        .frame(height:calculatedScrollViewHeight)
                        .onChange(of: calculatedScrollViewHeight) { oldHeight, newHeight in
                            viewModel.updateScrollViewHeight(newHeight)}
                        Spacer()//spacer for lowwer parts position at ZStack
                    }//VStack
                    //===================================Z2
                    // lower parts (or right parts)
                    //===================================Z2
                    VStack(spacing: 0) {
                        Spacer() // spacer for upper parts
                        numberDisplay()
                        tenkeyPad()
                        AdDisplay()
                    }//VStack
                }//ZStack
                .frame(width:calcWidth)
                if isPadAndNotCatalyst {Spacer()}
            }//HStack
            .onAppear {
                self.viewSize = bodygeometry.size
                viewModel.updateScrollViewHeight(calculatedScrollViewHeight)
            }
            .onChange(of: bodygeometry.size) { oldSize, newSize in self.viewSize = newSize}
        }//geometry Reader
    }//End of body
    
    //==================
    // grayBarView
    //==================
    struct grayBarView:View{
        var body : some View{
            Rectangle()
                .frame(width: 20)
                .foregroundColor(Color.gray.opacity(0.5))
        }
    }
    //==================
    //ScrollViewContent
    //==================
    func ScrollViewContent() -> some View{
        ScrollViewReader { proxy in
            //==============================
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.cellContents) { cellContent in
                        VStack(spacing: 0) {
                            Divider()
                            GeometryReader { geometry in
                                HStack(spacing: 0) {
                                    Text(cellContent.operatorSymbol)
                                        .font(.system(size: 24))
                                        .foregroundColor(cellContent.color)
                                        .frame(width: geometry.size.width * 0.15, alignment: .leading)
                                        .padding(.leading, geometry.size.width * 0.05)
                                    Spacer()
                                    Text(cellContent.text.isEmpty ? " " : cellContent.text)
                                        .font(.system(size: 24, weight: cellContent.operatorSymbol == "=" ? .bold : .regular))
                                        .foregroundColor(cellContent.color)
                                        .frame(alignment: .trailing)
                                        .padding(.trailing, geometry.size.width * 0.05)
                                }//HStack Table Display
                                .frame(height: 44, alignment: .center)
                            }//Geometry Reader
                        }//VStack Table row
                        .frame(height: viewModel.cellHeight)
                        .id(cellContent.id)
                    }//For Eacck
                    Divider()
                }//VStack End of Table
                //==============================
            }//Scroll View
            .background(Color.white)
            .onAppear {
                scrollViewProxy = proxy
            }
            .onChange(of: viewModel.cellContents) {oldContents, newContents in
                if let lastId = newContents.last?.id {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.linear(duration: 1.0)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            .offset(y: scrollViewOffset)
            .background(Color.gray)
        }//Scroll Reader (proxy)
    }
    //==================
    //numberDisplay
    //==================
    func numberDisplay() -> some View{
        HStack(spacing: 0) {
            Text(viewModel.displayOperator)
                .font(.system(size: 36))
                .foregroundColor(.blue)
                .frame(width: 45, alignment: .center)
                .padding(.leading, 15)
            Spacer()
            Text(viewModel.displayInput)
                .font(.system(size: 36))
                .foregroundColor(.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.trailing, 15)
        }
        .frame(height: inputDisplayHeight)
        .padding(.horizontal)
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.gray, lineWidth: 3)
        )
        //                        .padding(4)
        // 薄い青緑色の不透明背景
        .background(Color(red: 240/255, green: 255/255, blue: 255/255))
    }
    //==================
    //tenkeyPad
    //==================
    func tenkeyPad() -> some View{
        HStack(spacing: 8) {
            numberColumn(numbers: ["7", "4", "1", "0"])
            numberColumn(numbers: ["8", "5", "2", "00"])
            numberColumn(numbers: ["9", "6", "3", "."])
            operatorColumnPlusMinus()
            operatorColumnCAC()
        }//HStack
        .padding(8)
        .background(Color(red: 240/255, green: 240/255, blue: 240/255)) 
        .frame(width: appWidth)
    }
    
    //==================
    //operatorColumn +/-
    //==================
    //配列に従い縦方向に数字キーを並べる
    private func operatorColumnPlusMinus() -> some View {
        VStack(spacing: 8) {
            CustomPlusMinusButton(action: {
                viewModel.toggleSign()
                generateHapticFeedback()
            })
            .frame(width: buttonSize, height: buttonSize)
            OperatorButton(symbol: "-", action: {
                viewModel.setOperator("-")
                generateHapticFeedback()
            })
            .frame(width: buttonSize, height: buttonSize)
            OperatorButton(symbol: "+", action: {
                viewModel.setOperator("+")
                generateHapticFeedback()
            })
            .frame(width: buttonSize, height: buttonSize * 2 + 8)
        }//VStack Key
    }
    
    //==================
    //operatorColumn C/AC
    //==================
    //配列に従い縦方向に数字キーを並べる
    private func operatorColumnCAC() -> some View {
        VStack(spacing: 8) {
            CustomCACButton(
                shortPressAction: {
                    viewModel.clearCurrentInput()
                    generateHapticFeedback()
                    if viewModel.showACTooltip {
                        isTooltipVisible = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isTooltipVisible = false
                            viewModel.disableACTooltip()
                        }
                    }
                },
                longPressAction: {
                    performACAnimation()
                    generateHapticFeedback()
                }
            )
            .frame(width: buttonSize, height: buttonSize)
            .overlay(
                    isTooltipVisible ?
                    Text("Long press for AC")
                        .padding(6)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .offset(x:-40, y: -40)
                        .frame(width:100)
                    : nil
            )
            OperatorButton(symbol: "÷", action: {
                viewModel.setOperator("÷")
                generateHapticFeedback()
            }).frame(width: buttonSize, height: buttonSize)
            OperatorButton(symbol: "×", action: {
                viewModel.setOperator("×")
                generateHapticFeedback()
            }).frame(width: buttonSize, height: buttonSize)
            OperatorButton(symbol: "=", action: {
                viewModel.calculate()
                generateHapticFeedback()
            }).frame(width: buttonSize, height: buttonSize)
        }//VStack key
    }
    
    //==================
    //AdDisplay
    //==================
    func AdDisplay() -> some View{
    #if DEBUG
        Rectangle()
            .foregroundColor(Color(white: 0.95))
            .frame(width: appWidth, height: adBannerHeight)
    #else
        SmartAdBannerView(isATTAuthorized: $isATTAuthorized)
            .frame(width: appWidth, height: adBannerHeight)
    #endif
    }

    //==================
    //numberColumn
    //==================
    //配列に従い縦方向に数字キーを並べる
    private func numberColumn(numbers: [String]) -> some View {
        VStack(spacing: 8) {
            ForEach(numbers, id: \.self) { number in
                NumberButton(number: number, action: {
                    viewModel.addDigit(number)
                    generateHapticFeedback()
                })
                // button size
                .frame(width: buttonSize, height: buttonSize)
            }
        }
    }
    //==================
    // keypadHeight
    //==================
    private var keypadHeight: CGFloat {
        let numberOfButton: CGFloat = 4 // キーパッドの行数
        let verticalSpacing: CGFloat = 8 // ボタン間の垂直方向の間隔
        let verticalPadding: CGFloat = 8 * 2 // 上下のパディング（.padding(.vertical, 8)より）
        return (numberOfButton * buttonSize) + ((numberOfButton - 1) * verticalSpacing) + verticalPadding
    }
    //==================
    // buttonSize
    //==================
    private var buttonSize: CGFloat {
        // Total horizontal padding (8 * 6)
        let horizontalPadding: CGFloat = 48
        let buttonCount : CGFloat = 5
        let availableWidth = appWidth - horizontalPadding
        // 最小ボタンサイズとして44を使用
        let bsize = max(availableWidth / buttonCount, 44)
        return bsize
    }
    //NumberButton表示
    struct NumberButton: View {
        let number: String
        let action: () -> Void
        
        var body: some View {
            GeometryReader{Numgeometry in
                Button(action: action) {
                    Text(number)
                        .frame(width: Numgeometry.size.width, height: Numgeometry.size.height)
                        .background(
                            Circle()
                                .foregroundColor(Color.white)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray, lineWidth: 3)
                                )
                        )
                        .font(.system(size: Numgeometry.size.height * 3 / 6 , weight: .regular))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    //operatorColumn 配列に従い縦報告の演算子キーを生成する
    private func operatorColumn(operators: [String]) -> some View {
        VStack(spacing: 8) {
            ForEach(operators, id: \.self) { op in
                if op == "+" {
                    OperatorButton(symbol: op, action: { viewModel.setOperator(op) })
                    //
                    //button size (8 is the space between tow buttons)
                    //
                        .frame(width: buttonSize, height: buttonSize * 2 + 8)
                } else {
                    OperatorButton(symbol: op, action: {
                        switch op {
                        case "C": viewModel.clearCurrentInput()
                        case "AC": performACAnimation()
                        case "=": viewModel.calculate()
                        default: viewModel.setOperator(op)
                        }
                    })
                    //
                    // button size
                    //
                    .frame(width: buttonSize, height: buttonSize)
                }
            }
        }
    }
    // performACAnimation
    private func performACAnimation() {
        withAnimation(.easeInOut(duration: 0.9)) {
            scrollViewOffset = UIScreen.main.bounds.height - 416 // Adjust this value if needed
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            viewModel.allClear()
            withAnimation(.easeInOut(duration: 0.9)) {
                scrollViewOffset = 0
            }
        }
    }
    // generatehapticFeedback 新しい関数: 振動フィードバックを生成
    private func generateHapticFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    private var appWidth: CGFloat {
        return max(isPadAndNotCatalyst ? viewSize.width * 0.6 : viewSize.width, 320)
    }
}


let isPadAndNotCatalyst: Bool = {
    #if os(iOS)
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        if #available(iOS 14.0, *) {
            return isPad && !UIDevice.current.isRunningOnMac
        } else {
            return isPad
        }
    #else
        return false
    #endif
}()

private extension UIDevice {
    @available(iOS 14.0, *)
    var isRunningOnMac: Bool {
        return ProcessInfo.processInfo.isiOSAppOnMac || ProcessInfo.processInfo.isMacCatalystApp
    }
}

// OperatorButton
struct OperatorButton: View {
    let symbol: String
    let action: () -> Void
    
    var body: some View {
        GeometryReader{geometry in
            Button(action: action) {
                Text(symbol)
                    .frame(width: geometry.size.width, height:  geometry.size.height)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .foregroundColor(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.gray, lineWidth: 3)
                            )
                    )
                    .font(.system(size: geometry.size.width * 0.5, weight: .regular))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.gray)
            }
        }
    }
}

#Preview {
    ContentView(viewModel: ContentViewModel(), isATTAuthorized: .constant(false))
}
