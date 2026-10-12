import UIKit
extension ScreenViewController {
    static let steps=["Cut your cords","Prepare the dowel","Tie the first row","Add more rows","Trim the fringe","Finish and hang"]
    static let instructions=["Measure six equal lengths of cotton cord. Cut carefully, leaving extra length for the fringe.","Place your dowel on a flat surface. Mark evenly spaced positions for each cord.","Fold a cord in half, place the loop over the dowel, and pull the ends through. Repeat across the row.","Work across the row, keeping the knots evenly spaced. Add texture with the wool yarn.","Comb out the fringe and trim it slowly to your preferred shape.","Attach a hanging cord, check that the dowel is balanced, and hang your finished weave."]
    var projectSteps: [String] { coordinator.currentProject?.stepTitles ?? Self.steps }
    func buildMaking() {
        let project = coordinator.currentProject
        body.spacing = 10
        switch screen.id {
        case "M01": buildMakeHome()
        case "M02":
            toolbar(""); heading("Start a new project", subtitle: "Turn inspiration into something real.")
            let cover = makeCover("make-weave", ratio: 0.76); cover.widthAnchor.constraint(equalToConstant: 145).isActive = true
            let hero = RoomUI.stack([cover, action("Change photo", "@photo", icon: "photo")], axis: .horizontal); hero.alignment = .center; add(RoomUI.card(hero, inset: 8))
            makeField("Project name", key: "name", value: "Woven wall hanging")
            add(RoomUI.label("Tutorial (optional)", size: 14, weight: .semibold))
            add(makeLink("Woven Wall Hanging\nfor Beginners", subtitle: "Step-by-step tutorial", asset: "make-weave", code: "D04"))
            add(RoomUI.label("Choose a space", size: 14, weight: .semibold)); add(makeLink(coordinator.selectedSpace, asset: "space-reading", code: "@chooseSpace"))
            materialChecklist(); add(action("Create project", "@createProject", primary: true))
        case "M03":
            toolbar("", trailing: "ellipsis", action: "@projectMenu"); heading(project?.name ?? "Woven wall hanging")
            add(RoomUI.label("\(project?.completedSteps ?? 0) of \(project?.totalSteps ?? 6) steps · \(project?.isComplete == true ? "Finished" : "In progress")", size: 14, color: .secondaryLabel))
            let progress = UIProgressView(progressViewStyle: .bar); progress.progressTintColor = .roomGreen; progress.trackTintColor = UIColor(white: 0.90, alpha: 1)
            progress.progress = Float(project?.completedSteps ?? 0) / Float(max(project?.totalSteps ?? 6, 1)); progress.heightAnchor.constraint(equalToConstant: 8).isActive = true; progress.layer.cornerRadius = 4; progress.clipsToBounds = true; add(progress)
            let links = RoomUI.stack([action(project?.space ?? coordinator.selectedSpace, "S02", icon: "house"), action("Tutorial", "D04", icon: "book")], axis: .horizontal); links.distribution = .fillEqually; add(RoomUI.card(links, inset: 4))
            materialChecklist()
            add(RoomUI.label("Progress", size: 16, weight: .semibold))
            let progressPhoto = makeCover("knot-hands", ratio: 0.68)
            let note = RoomUI.stack([RoomUI.label(project?.notes.isEmpty == false ? project!.notes : "Keep a photo or note as you make.", size: 13), action("Project notes", "M06", icon: "note.text")], spacing: 8)
            let noteCard = RoomUI.card(note, inset: 10); noteCard.backgroundColor = UIColor(red: 0.91, green: 0.95, blue: 0.98, alpha: 1)
            let progressRow = RoomUI.stack([progressPhoto, noteCard], axis: .horizontal); progressRow.distribution = .fillEqually; add(progressRow)
            add(RoomUI.label("Steps", size: 16, weight: .semibold)); makeStepList()
            add(action(project?.isComplete == true ? "View finished make" : "Continue making", project?.isComplete == true ? "M05" : "M04", primary: true))
        case "M04":
            let index = min(makingStep ?? project?.completedSteps ?? 0, projectSteps.count - 1)
            makingStep = index
            toolbar("\(index + 1) of \(project?.totalSteps ?? 6)", trailing: "ellipsis", action: "@projectMenu")
            heading(projectSteps[index], subtitle: index == 2 ? "Create a row of square knots on your dowel." : "Take your time and enjoy the process.")
            _ = photo("knot-hands", ratio: 0.94)
            let copy = project?.stepTitles != nil ? "Complete this step at your own pace. Add a photo or note to record your process." : index == 2 ? "1. Fold a cord in half and place it over the dowel.\n2. Pull the ends through the loop.\n3. Tighten to create a square knot.\n4. Repeat across the row." : Self.instructions[min(index, Self.instructions.count - 1)]
            let instruction = RoomUI.card(RoomUI.label(copy, size: 14), inset: 16); instruction.backgroundColor = UIColor(red: 0.91, green: 0.95, blue: 0.98, alpha: 1); add(instruction)
            let tools = RoomUI.stack([action("Add photo", "@photo", icon: "camera"), action("Note", "M06", icon: "note.text")], axis: .horizontal); tools.distribution = .fillEqually; add(RoomUI.card(tools, inset: 0))
            let previous = action("Previous", "@previousStep"); previous.isEnabled = index > 0; add(previous)
            add(action(index < (project?.completedSteps ?? 0) ? "Next step" : "Mark step complete", "@advance", primary: true))
        case "M05":
            toolbar("")
            let title = RoomUI.label("Made by you", size: 32, weight: .bold); title.textAlignment = .center; add(title)
            let subtitle = RoomUI.label("Your project is complete!", size: 16, color: .secondaryLabel); subtitle.textAlignment = .center; add(subtitle)
            let badge = RoomUI.label("✓  \(project?.completedSteps ?? 0) of \(project?.totalSteps ?? 6) steps completed", size: 14); badge.textAlignment = .center
            let badgeCard = RoomUI.card(badge, inset: 10); badgeCard.backgroundColor = .roomYellow; add(badgeCard)
            add(makeCover("make-finished", ratio: 0.83))
            add(RoomUI.card(RoomUI.stack([RoomUI.label("Attach to a space", size: 14, weight: .semibold), action(coordinator.selectedSpace, "@chooseSpace", icon: "house"), RoomUI.label("Visibility", size: 14, weight: .semibold), RoomUI.label("Only me · saved on this device", size: 14, color: .secondaryLabel)])))
            add(action("Save to space", "@place", primary: true)); add(action("Share your make", "C02", icon: "square.and.arrow.up"))
        case "M06":
            toolbar("Project notes", trailing: "ellipsis", action: "@projectMenu")
            add(makeLink(project?.name ?? "Your project", subtitle: project?.space ?? coordinator.selectedSpace, asset: "make-weave", code: "M03"))
            add(RoomUI.label("Add a note", size: 20, weight: .semibold)); add(makeCover("make-note", ratio: 0.47))
            add(action("Add photo", "@photo", icon: "camera")); editor("Your note", key: "note", value: project?.notes ?? "")
            add(action("Save note", "@saveNote", primary: true)); add(RoomUI.label("Previous notes", size: 17, weight: .semibold))
            for note in project?.noteHistory ?? [] { add(RoomUI.card(RoomUI.label(note, size: 15))) }
            if (project?.noteHistory ?? []).isEmpty { add(RoomUI.label("Your saved note history will appear here.", size: 14, color: .secondaryLabel)) }
        default:
            toolbar("Edit project", trailing: "ellipsis", action: "@projectMenu")
            add(makeCover("make-edit", ratio: 0.52)); add(action("Change photo", "@photo", icon: "camera"))
            makeField("Project title", key: "name", value: project?.name ?? "")
            add(RoomUI.label("Space", size: 14, weight: .semibold)); add(makeLink(coordinator.selectedSpace, asset: "space-reading", code: "@chooseSpace"))
            materialChecklist(); add(RoomUI.label("Steps", size: 17, weight: .semibold)); makeStepList(); add(action("Edit steps", "@editSteps", icon: "pencil")); add(RoomUI.label("One step per line. Changing completed steps updates the recorded progress.", size: 12, color: .secondaryLabel))
            add(action("Save changes", "@editProject", primary: true))
        }
    }
    private func makeField(_ title: String, key: String, value: String) {
        let field = UITextField(); field.text = value; field.font = .systemFont(ofSize: 15)
        field.borderStyle = .roundedRect; field.backgroundColor = .white; field.returnKeyType = .done
        field.accessibilityIdentifier = "input.\(key)"; field.accessibilityLabel = title
        field.heightAnchor.constraint(equalToConstant: 40).isActive = true
        field.addAction(UIAction { [weak field] _ in field?.resignFirstResponder() }, for: .editingDidEndOnExit)
        fields[key] = field; add(RoomUI.stack([RoomUI.label(title, size: 13, weight: .medium), field], spacing: 5))
    }
    private func makeCover(_ asset: String, ratio: CGFloat) -> UIImageView {
        let cover = RoomUI.image(asset, ratio: ratio, radius: 12)
        let name = screen.id == "M02" ? coordinator.pendingProjectPhoto : coordinator.currentProject.flatMap { coordinator.store.state.projectPhotos?[$0.id.uuidString]?.last }
        if let image = localPhoto(name) { cover.image = image }; return cover
    }
    private func makeLink(_ title: String, subtitle: String? = nil, asset: String, code: String) -> UIView {
        let cover = RoomUI.image(asset, ratio: 1, radius: 7); cover.widthAnchor.constraint(equalToConstant: 58).isActive = true
        let button = action(title, code); button.contentHorizontalAlignment = .leading; button.configuration?.baseForegroundColor = .label
        let text = RoomUI.stack([button], spacing: 0); if let subtitle { text.addArrangedSubview(RoomUI.label(subtitle, size: 12, color: .secondaryLabel)) }
        let chevron = RoomUI.label("›", size: 24, color: .secondaryLabel)
        let row = RoomUI.stack([cover, text, chevron], axis: .horizontal, spacing: 10); row.alignment = .center; return RoomUI.card(row, inset: 8)
    }
    private func makeStepList() {
        let done = coordinator.currentProject?.completedSteps ?? 0
        let stack = RoomUI.stack(spacing: 0)
        for (index, title) in projectSteps.enumerated() {
            let label = RoomUI.label("\(index < done ? "✓" : "○")   \(index + 1).  \(title)", size: 14, color: index < done ? .roomGreen : .label)
            let row = RoomUI.card(label, inset: 10); row.layer.cornerRadius = 0
            if index == done { row.backgroundColor = UIColor.roomYellow.withAlphaComponent(0.25) }; stack.addArrangedSubview(row)
        }
        let card = RoomUI.card(stack, inset: 0); card.clipsToBounds = true; add(card)
    }
    func materialChecklist() {
        add(RoomUI.label(screen.id == "M02" ? "Materials checklist" : "Materials", size: 16, weight: .semibold))
        let creating = screen.id == "M02"
        let values = creating ? coordinator.draftMaterials : coordinator.currentProject?.materials ?? ["Cotton cord", "Wooden dowel", "Scissors"]
        let checked = creating ? coordinator.draftCheckedMaterials : coordinator.currentProject?.checkedMaterials ?? []
        let stack = RoomUI.stack(spacing: 4)
        for (index, name) in values.enumerated() {
            let asset = ["cotton", "dowel", "scissors"][min(index, 2)]
            let photo = RoomUI.image(asset, ratio: 0.8, radius: 6); photo.widthAnchor.constraint(equalToConstant: 40).isActive = true
            let button = RoomUI.button(name, icon: checked.contains(name) ? "checkmark.circle.fill" : "circle") { [weak self] in
                guard let self else { return }
                if creating { if !self.coordinator.draftCheckedMaterials.insert(name).inserted { self.coordinator.draftCheckedMaterials.remove(name) } }
                else if let id = self.coordinator.currentProject?.id { self.coordinator.perform { try self.coordinator.store.update { state in if let i = state.projects.firstIndex(where: { $0.id == id }) { var selected = state.projects[i].checkedMaterials ?? []; if !selected.insert(name).inserted { selected.remove(name) }; state.projects[i].checkedMaterials = selected } } } }
                self.refresh()
            }
            button.configuration?.imagePlacement = .trailing
            button.configuration?.baseForegroundColor = .label
            button.configuration?.titleTextAttributesTransformer = .init { attributes in var attributes = attributes; attributes.font = .systemFont(ofSize: 13); return attributes }
            button.contentHorizontalAlignment = .leading; button.accessibilityIdentifier = "material.\(index)"
            let row = RoomUI.stack([photo, button], axis: .horizontal, spacing: 10); row.alignment = .center; stack.addArrangedSubview(row)
        }
        add(RoomUI.card(stack, inset: 8)); if screen.id != "M03" { add(action("Add another material", "@material", icon: "plus.circle")) }
    }
}
