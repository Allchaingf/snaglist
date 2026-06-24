//
//  SignatureCanvas.swift
//  Snaglist
//
//  A lightweight finger-drawing signature pad. A custom UIView collects touch
//  points into UIBezierPaths and renders them; the controller exposes clear()
//  and exportImage() and publishes whether any strokes exist (to gate the
//  Accept button). Deliberately NOT PencilKit — fully iOS 14 safe.
//

import SwiftUI
import UIKit

final class SignatureController: ObservableObject {
    @Published var hasStrokes = false
    fileprivate weak var view: SignatureDrawingView?

    func clear() {
        view?.clear()
        hasStrokes = false
    }
    /// Renders the strokes onto a white background for embedding in the PDF.
    func exportImage() -> UIImage? { view?.renderImage() }
}

final class SignatureDrawingView: UIView {
    var onChange: ((Bool) -> Void)?
    private var paths: [UIBezierPath] = []
    private var current: UIBezierPath?
    private let strokeColor = UIColor(hex: 0x0F172A)
    private let lineWidth: CGFloat = 2.6

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = false
        isExclusiveTouch = true
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self) else { return }
        let path = UIBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: p)
        current = path
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self) else { return }
        current?.addLine(to: p)
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let path = current { paths.append(path); current = nil }
        setNeedsDisplay()
        onChange?(!paths.isEmpty)
    }

    override func draw(_ rect: CGRect) {
        strokeColor.setStroke()
        for path in paths { path.stroke() }
        current?.stroke()
    }

    func clear() {
        paths.removeAll(); current = nil
        setNeedsDisplay()
        onChange?(false)
    }

    func renderImage() -> UIImage? {
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: bounds).fill()
            strokeColor.setStroke()
            for path in paths { path.stroke() }
        }
    }
}

struct SignatureCanvas: UIViewRepresentable {
    @ObservedObject var controller: SignatureController

    func makeUIView(context: Context) -> SignatureDrawingView {
        let v = SignatureDrawingView()
        v.onChange = { has in DispatchQueue.main.async { controller.hasStrokes = has } }
        controller.view = v
        return v
    }
    func updateUIView(_ uiView: SignatureDrawingView, context: Context) {
        controller.view = uiView
    }
}
