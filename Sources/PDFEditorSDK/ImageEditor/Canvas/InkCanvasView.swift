import UIKit

struct InkStroke: Identifiable {
    let id: UUID
    var points: [CGPoint]
    var color: UIColor
    var lineWidth: CGFloat

    init(id: UUID = UUID(), points: [CGPoint], color: UIColor, lineWidth: CGFloat) {
        self.id = id
        self.points = points
        self.color = color
        self.lineWidth = lineWidth
    }
}

final class InkCanvasView: UIView {
    var strokes: [InkStroke] = []
    var liveStroke: InkStroke?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isOpaque = false
    }

    private func denoisedPoints(_ points: [CGPoint], iterations: Int = 3) -> [CGPoint] {
        guard points.count > 2 else { return points }
        var result = points
        for _ in 0..<iterations {
            var pass = [result[0]]
            for i in 1..<(result.count - 1) {
                pass.append(CGPoint(
                    x: (result[i - 1].x + result[i].x * 2 + result[i + 1].x) / 4,
                    y: (result[i - 1].y + result[i].y * 2 + result[i + 1].y) / 4
                ))
            }
            pass.append(result[result.count - 1])
            result = pass
        }
        return result
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let allStrokes = strokes + (liveStroke.map { [$0] } ?? [])
        for stroke in allStrokes {
            guard stroke.points.count >= 2 else {
                if let point = stroke.points.first {
                    context.setFillColor(stroke.color.cgColor)
                    let dotRadius = stroke.lineWidth / 2
                    context.fillEllipse(in: CGRect(
                        x: point.x - dotRadius,
                        y: point.y - dotRadius,
                        width: stroke.lineWidth,
                        height: stroke.lineWidth
                    ))
                }
                continue
            }
            stroke.color.setStroke()
            context.setLineWidth(stroke.lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.beginPath()
            let pts = denoisedPoints(stroke.points)
            let n = pts.count
            context.move(to: pts[0])
            if n == 2 {
                context.addLine(to: pts[1])
            } else {
                for i in 0..<(n - 1) {
                    let p0 = pts[max(i - 1, 0)]
                    let p1 = pts[i]
                    let p2 = pts[i + 1]
                    let p3 = pts[min(i + 2, n - 1)]
                    let cp1 = CGPoint(
                        x: p1.x + (p2.x - p0.x) / 6,
                        y: p1.y + (p2.y - p0.y) / 6
                    )
                    let cp2 = CGPoint(
                        x: p2.x - (p3.x - p1.x) / 6,
                        y: p2.y - (p3.y - p1.y) / 6
                    )
                    context.addCurve(to: p2, control1: cp1, control2: cp2)
                }
            }
            context.strokePath()
        }
    }
}
