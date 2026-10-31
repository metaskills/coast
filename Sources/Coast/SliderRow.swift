import AppKit

/// A labeled slider that lives inside the menu bar menu.
final class SliderRow: NSObject {
    let menuItem = NSMenuItem()
    private let label = NSTextField(labelWithString: "")
    private let readout = NSTextField(labelWithString: "")
    private let slider: NSSlider
    private let format: (Double) -> String
    private let onChange: (Double) -> Void

    var value: Double {
        get { slider.doubleValue }
        set {
            slider.doubleValue = newValue
            readout.stringValue = format(newValue)
        }
    }

    init(title: String, range: ClosedRange<Double>, value: Double,
         format: @escaping (Double) -> String, onChange: @escaping (Double) -> Void) {
        self.slider = NSSlider(value: value, minValue: range.lowerBound, maxValue: range.upperBound, target: nil, action: nil)
        self.format = format
        self.onChange = onChange
        super.init()

        label.stringValue = title
        label.font = .menuFont(ofSize: 0)
        readout.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        readout.textColor = .secondaryLabelColor
        readout.alignment = .right
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(changed)
        slider.controlSize = .small

        let view = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 46))
        for v in [label, readout, slider] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            readout.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            readout.firstBaselineAnchor.constraint(equalTo: label.firstBaselineAnchor),
            slider.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: readout.trailingAnchor),
            slider.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
        ])
        menuItem.view = view
        self.value = value
    }

    @objc private func changed() {
        readout.stringValue = format(slider.doubleValue)
        onChange(slider.doubleValue)
    }
}
