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
    func settingsView(_ settingsView: SettingsView, didUpdateGlobalSettings: GlobalSettings)
    func settingsView(_ settingsView: SettingsView, didUpdateTeamSettings: [TeamSettings])
}

func labelledStackView(fromViews views: [(String, UIView)]) -> UIStackView {
    let rowStackViews: [UIStackView] = views.map {
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
    stackView.spacing = 10
    stackView.axis = .vertical
    stackView.distribution = .fillEqually

    return stackView
}

class TeamSettingsView: UIView {
    let separationStrengthSlider = UISlider()
    let cohesionStrengthSlider = UISlider()
    let alignmentStrengthSlider = UISlider()
    let teamStrengthSlider = UISlider()
    let speedSlider = UISlider()

    let separationRangeSlider = UISlider()
    let cohesionRangeSlider = UISlider()
    let alignmentRangeSlider = UISlider()

    var currentSettings: TeamSettings
    var onUpdate: (() -> ())?

    init(withSettings settings: TeamSettings) {
        currentSettings = settings
        super.init(frame: .zero)

        teamStrengthSlider.value = settings.teamStrength
        separationStrengthSlider.value = settings.separationStrength
        cohesionStrengthSlider.value = settings.cohesionStrength
        alignmentStrengthSlider.value = settings.alignmentStrength
        speedSlider.value = settings.maximumSpeedMultiplier

        separationRangeSlider.value = settings.separationRange
        cohesionRangeSlider.value = settings.cohesionRange
        alignmentRangeSlider.value = settings.alignmentRange

        let stackView = createStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        addConstraints([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leftAnchor.constraint(equalTo: leftAnchor),
            stackView.rightAnchor.constraint(equalTo: rightAnchor)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func createStackView() -> UIStackView {
        let sliders: [(String, UISlider, Float, Float)] = [
            ("Teams", teamStrengthSlider, -3, 3),
            ("Speed", speedSlider, 0, 3),
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

            $0.1.addTarget(self, action: #selector(onSettingsUpdate), for: .touchDragInside)
            $0.1.addTarget(self, action: #selector(onSettingsUpdate), for: .touchDragOutside)
        }

        return labelledStackView(fromViews: sliders.map { ($0.0, $0.1) })
    }

    @objc func onSettingsUpdate() {
        currentSettings = TeamSettings(
            separationStrength: separationStrengthSlider.value,
            cohesionStrength: cohesionStrengthSlider.value,
            alignmentStrength: alignmentStrengthSlider.value,
            teamStrength: teamStrengthSlider.value,
            maximumSpeedMultiplier: speedSlider.value,
            separationRange: separationRangeSlider.value,
            cohesionRange: cohesionRangeSlider.value,
            alignmentRange: alignmentRangeSlider.value
        )
        print(currentSettings)
        onUpdate?()
    }
}

class GlobalSettingsView: UIView {
    let wrapSwitch = UISwitch()
    let teamsSwitch = UISwitch()

    var currentSettings: GlobalSettings
    var onUpdate: (() -> ())?

    init(withSettings settings: GlobalSettings) {
        currentSettings = settings
        super.init(frame: .zero)

        wrapSwitch.isOn = settings.wrapEnabled
        teamsSwitch.isOn = settings.teamsEnabled

        let stackView = createStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        addConstraints([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leftAnchor.constraint(equalTo: leftAnchor),
            stackView.rightAnchor.constraint(equalTo: rightAnchor)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func createStackView() -> UIStackView {
        let switches: [(String, UISwitch)] = [
            ("Teams", teamsSwitch),
            ("Wrap", wrapSwitch)
        ]

        switches.forEach {
            $0.1.addTarget(self, action: #selector(onSettingsUpdate), for: .valueChanged)
        }

        return labelledStackView(fromViews: switches.map { ($0.0, $0.1) })
    }

    @objc func onSettingsUpdate() {
        currentSettings = GlobalSettings(teamsEnabled: teamsSwitch.isOn, wrapEnabled: wrapSwitch.isOn)
        onUpdate?()
    }
}

class SettingsView: UIView {
    weak var delegate: SettingsViewDelegate?

    let globalSettingsView: GlobalSettingsView
    let teamSettingsViews: [TeamSettingsView]

    let currentSettingsView = UIView()

    init(globalSettings: GlobalSettings, teamSettings: [TeamSettings]) {
        teamSettingsViews = teamSettings.map { TeamSettingsView(withSettings: $0) }
        globalSettingsView = GlobalSettingsView(withSettings: globalSettings)
        super.init(frame: .zero)
        teamSettingsViews.forEach { $0.onUpdate = self.updateTeamSettings }
        globalSettingsView.onUpdate = self.updateGlobalSettings

        let settingsSelectionView = UISegmentedControl(items: ["Global", "Team blue", "Team red"])
        settingsSelectionView.selectedSegmentIndex = 0
        settingsSelectionView.addTarget(self, action: #selector(settingsSelectionChanged), for: .valueChanged)

        addSubview(currentSettingsView)
        addConstraints([
            currentSettingsView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            currentSettingsView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            currentSettingsView.leftAnchor.constraint(equalTo: leftAnchor, constant: 20),
            currentSettingsView.rightAnchor.constraint(lessThanOrEqualTo: rightAnchor, constant: -20),
            currentSettingsView.widthAnchor.constraint(greaterThanOrEqualToConstant: 400)
        ])

        let stackView = UIStackView(arrangedSubviews: [settingsSelectionView, currentSettingsView])
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        addConstraints([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            stackView.leftAnchor.constraint(equalTo: leftAnchor, constant: 20),
            stackView.rightAnchor.constraint(lessThanOrEqualTo: rightAnchor, constant: -20),
            stackView.widthAnchor.constraint(greaterThanOrEqualToConstant: 400)
        ])

        showChild(view: globalSettingsView)
    }

    @objc func settingsSelectionChanged(control: UISegmentedControl) {
        switch control.selectedSegmentIndex {
        case 0:
            showChild(view: globalSettingsView)
        case 1:
            showChild(view: teamSettingsViews[0])
        case 2:
            showChild(view: teamSettingsViews[1])
        default:
            break
        }
    }

    func showChild(view: UIView) {
        currentSettingsView.subviews.forEach { $0.removeFromSuperview() }
        currentSettingsView.removeConstraints(currentSettingsView.constraints)
        view.translatesAutoresizingMaskIntoConstraints = false
        currentSettingsView.addSubview(view)
        currentSettingsView.addConstraints([
            view.topAnchor.constraint(equalTo: currentSettingsView.topAnchor),
            view.bottomAnchor.constraint(equalTo: currentSettingsView.bottomAnchor),
            view.leftAnchor.constraint(equalTo: currentSettingsView.leftAnchor),
            view.rightAnchor.constraint(equalTo: currentSettingsView.rightAnchor)
        ])
    }

    func updateGlobalSettings() {
        let settings = globalSettingsView.currentSettings
        delegate?.settingsView(self, didUpdateGlobalSettings: settings)
    }

    func updateTeamSettings() {
        let settings = teamSettingsViews.map { $0.currentSettings }
        delegate?.settingsView(self, didUpdateTeamSettings: settings)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
