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
    let teamStrengthSlider = UISlider()

    let separationRangeSlider = UISlider()
    let cohesionRangeSlider = UISlider()
    let alignmentRangeSlider = UISlider()

    let wrapSwitch = UISwitch()
    let teamsSwitch = UISwitch()

    weak var delegate: SettingsViewDelegate?

    init(settings: Settings) {
        super.init(frame: .zero)

        teamStrengthSlider.value = settings.teamStrength
        separationStrengthSlider.value = settings.separationStrength
        cohesionStrengthSlider.value = settings.cohesionStrength
        alignmentStrengthSlider.value = settings.alignmentStrength

        separationRangeSlider.value = settings.separationRange
        cohesionRangeSlider.value = settings.cohesionRange
        alignmentRangeSlider.value = settings.alignmentRange

        wrapSwitch.isOn = settings.wrapEnabled
        teamsSwitch.isOn = settings.teamsEnabled

        let sliders: [(String, UISlider, Float, Float)] = [
            ("Teams", teamStrengthSlider, -3, 3),
            ("Separation", separationStrengthSlider, 0, 2),
            ("Cohesion", cohesionStrengthSlider, 0, 2),
            ("Alignment", alignmentStrengthSlider, 0, 2)
//            ("SRange", separationRangeSlider, 1),
//            ("CRange", cohesionRangeSlider, 1),
//            ("ARange", alignmentRangeSlider, 1),
        ]

        sliders.forEach {
            $0.1.minimumValue = $0.2
            $0.1.maximumValue = $0.3

            $0.1.addTarget(self, action: #selector(updateSettings), for: .touchDragInside)
            $0.1.addTarget(self, action: #selector(updateSettings), for: .touchDragOutside)
        }

        let switches: [(String, UISwitch)] = [
            ("Teams", teamsSwitch),
            ("Wrap", wrapSwitch)
        ]

        switches.forEach {
            $0.1.addTarget(self, action: #selector(updateSettings), for: .valueChanged)
        }

        let subViews: [(String, UIView)] = switches.map { ($0.0, $0.1) } + sliders.map { ($0.0, $0.1) }

        let rowStackViews: [UIStackView] = subViews.map {
            let (label, slider) = $0
            let labelView = UILabel()
            labelView.text = label
            labelView.textColor = .white
            labelView.widthAnchor.constraint(equalToConstant: 100).isActive = true

            let stackView = UIStackView(arrangedSubviews: [labelView, slider])
            stackView.spacing = 20
            return stackView
        }

        let stackView = UIStackView(arrangedSubviews: rowStackViews)
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        addConstraints([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            stackView.leftAnchor.constraint(equalTo: leftAnchor, constant: 20),
            stackView.rightAnchor.constraint(lessThanOrEqualTo: rightAnchor, constant: -20),
            stackView.widthAnchor.constraint(greaterThanOrEqualToConstant: 400)//(equalTo: rightAnchor, constant: -20),
        ])
    }

    @objc func updateSettings() {
        let settings = Settings(
            separationStrength: separationStrengthSlider.value,
            cohesionStrength: cohesionStrengthSlider.value,
            alignmentStrength: alignmentStrengthSlider.value,
            teamStrength: teamStrengthSlider.value,
            separationRange: separationRangeSlider.value,
            cohesionRange: cohesionRangeSlider.value,
            alignmentRange: alignmentRangeSlider.value,
            teamsEnabled: teamsSwitch.isOn,
            wrapEnabled: wrapSwitch.isOn)

        delegate?.settingsView(self, didUpdateSettings: settings)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
