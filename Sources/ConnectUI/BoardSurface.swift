import ConnectCore
import SwiftUI

/// The complete board is one drawing surface. Its equatable boundary prevents
/// the shared countdown refresh from invalidating an unchanged board drawing.
struct BoardSurface: View, Equatable {
    let board: Board
    var lastMove: Move?
    var interactive = false
    var identifier = "demo"
    var onDrop: (Int) -> Void = { _ in }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.board == rhs.board && lhs.lastMove == rhs.lastMove &&
        lhs.interactive == rhs.interactive && lhs.identifier == rhs.identifier
    }

    var body: some View {
        GeometryReader { geometry in
            let cell = geometry.size.width / 7
            Canvas { context, size in
                let diameter = cell * 0.77
                for row in 0..<6 {
                    for column in 0..<7 {
                        let index = row * 7 + column
                        let center = CGPoint(x: cell * (Double(column) + 0.5),
                                             y: cell * (Double(row) + 0.5))
                        let rect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                                          width: diameter, height: diameter)
                        let path = Path(ellipseIn: rect)
                        if let player = board.cells[index] {
                            context.fill(path, with: .linearGradient(
                                Gradient(colors: [player.color, player.color.opacity(0.8)]),
                                startPoint: CGPoint(x: center.x, y: rect.minY),
                                endPoint: CGPoint(x: center.x, y: rect.maxY)))
                            // A diamond and a dot give the colors a second identity.
                            if player == .gold {
                                var diamond = Path()
                                let radius = diameter * 0.13
                                diamond.move(to: CGPoint(x: center.x, y: center.y - radius))
                                diamond.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                                diamond.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                                diamond.addLine(to: CGPoint(x: center.x - radius, y: center.y))
                                diamond.closeSubpath()
                                context.fill(diamond, with: .color(Palette.background.opacity(0.45)))
                            } else {
                                context.fill(Path(ellipseIn: CGRect(x: center.x - diameter * 0.1,
                                    y: center.y - diameter * 0.1, width: diameter * 0.2,
                                    height: diameter * 0.2)), with: .color(Palette.background.opacity(0.4)))
                            }
                        } else {
                            context.fill(path, with: .color(Palette.hole))
                            context.stroke(path, with: .color(.white.opacity(0.04)), lineWidth: 1)
                        }
                        if board.outcome.winningCells.contains(index) {
                            context.stroke(Path(ellipseIn: rect.insetBy(dx: 2, dy: 2)),
                                           with: .color(.white), lineWidth: 2)
                        } else if lastMove?.index == index {
                            context.stroke(Path(ellipseIn: rect.insetBy(dx: 2, dy: 2)),
                                           with: .color(.white.opacity(0.7)), lineWidth: 1.5)
                        }
                    }
                }
            }
            .accessibilityHidden(true)
            if interactive {
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        Button { onDrop(column) } label: {
                            Color.clear.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!board.legalColumns.contains(column))
                        .accessibilityLabel("Column \(column + 1)")
                        .accessibilityValue(columnDescription(column))
                        .accessibilityHint("Drop a \(board.turn.name) piece in this column")
                        .accessibilityIdentifier("\(identifier)-column-\(column)")
                    }
                }
            }
        }
        .aspectRatio(7.0 / 6.0, contentMode: .fit)
        .padding(5)
        .background(Palette.board.gradient, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: interactive ? .contain : .ignore)
        .accessibilityLabel(interactive ? "Game board" : "Connect Four board illustration")
    }

    private func columnDescription(_ column: Int) -> String {
        let contents = (0..<6).compactMap { row -> String? in
            board[row, column].map { "row \(row + 1) \($0.name)" }
        }
        return contents.isEmpty ? "Empty" : contents.joined(separator: ", ")
    }
}
