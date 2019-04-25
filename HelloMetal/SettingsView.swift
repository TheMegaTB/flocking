/// Copyright (c) 2019 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit

protocol SettingsViewDelegate: class {
    func settingsView(_ settingsView: SettingsView, didUpdateSettings: Settings)
}

class SettingsView: UIView {
    let separationStrengthSlider = UISlider()
    let cohesionStrengthSlider = UISlider()
    let alignmentStrengthSlider = UISlider()

    let separationRangeSlider = UISlider()
    let cohesionRangeSlider = UISlider()
    let alignmentRangeSlider = UISlider()

    weak var delegate: SettingsViewDelegate?

    init(settings: Settings) {
        super.init(frame: .zero)

        separationStrengthSlider.value = settings.separationStrength
        cohesionStrengthSlider.value = settings.cohesionStrength
        alignmentStrengthSlider.value = settings.alignmentStrength

        separationRangeSlider.value = settings.separationRange
        cohesionRangeSlider.value = settings.cohesionRange
        alignmentRangeSlider.value = settings.alignmentRange

        let sliders: [(String, UISlider, Float)] = [
            ("Separation", separationStrengthSlider, 0.01),
            ("Cohesion", cohesionStrengthSlider, 0.01),
            ("Alignment", alignmentStrengthSlider, 0.01)
//            ("SRange", separationRangeSlider, 1),
//            ("CRange", cohesionRangeSlider, 1),
//            ("ARange", alignmentRangeSlider, 1),
        ]

        let sliderStackViews: [UIStackView] = sliders.map {
            let (label, slider, _) = $0
            let labelView = UILabel()
            labelView.text = label
            labelView.widthAnchor.constraint(equalToConstant: 100).isActive = true

            let stackView = UIStackView(arrangedSubviews: [labelView, slider])
            stackView.spacing = 20
            return stackView
        }

        let stackView = UIStackView(arrangedSubviews: sliderStackViews)
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        addConstraints([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            stackView.leftAnchor.constraint(equalTo: leftAnchor, constant: 20),
            stackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -20)
        ])

        sliders.forEach {
            $0.1.minimumValue = 0
            $0.1.maximumValue = $0.2

            $0.1.addTarget(self, action: #selector(updateSettings), for: .touchDragInside)
            $0.1.addTarget(self, action: #selector(updateSettings), for: .touchDragOutside)
        }
    }

    @objc func updateSettings() {
        let settings = Settings(
            separationStrength: separationStrengthSlider.value,
            cohesionStrength: cohesionStrengthSlider.value,
            alignmentStrength: alignmentStrengthSlider.value,
            separationRange: separationRangeSlider.value,
            cohesionRange: cohesionRangeSlider.value,
            alignmentRange: alignmentRangeSlider.value)

        delegate?.settingsView(self, didUpdateSettings: settings)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
