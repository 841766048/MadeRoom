import XCTest
final class MadeRoomUITests: XCTestCase {
    func testDesignedDialogCancellationAndSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-state", "--screen", "X11"]
        app.launch()
        tap(app.buttons["action.X11.@deleteProject"], in: app)
        XCTAssertTrue(app.buttons["dialog.action.Delete project"].waitForExistence(timeout: 3))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Dialog-Delete"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["dialog.action.Cancel"].tap()
        XCTAssertTrue(app.buttons["action.X11.@deleteProject"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["dialog.action.Delete project"].exists)
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-test-state", "--screen", "P02"]
        app.launch()
        app.buttons["action.P02.@savedMenu"].tap()
        XCTAssertTrue(app.buttons["dialog.action.New collection"].waitForExistence(timeout: 3))
        let menu = XCTAttachment(screenshot: app.screenshot()); menu.name = "Dialog-Menu"; menu.lifetime = .keepAlways; add(menu)
        app.buttons["dialog.action.New collection"].tap()
        XCTAssertTrue(app.otherElements["screen.P10"].waitForExistence(timeout: 3))
    }
    func testSearchFilterDraftAndApply() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-state", "--screen", "D02"]
        app.launch()
        app.buttons["action.D02.@filters"].tap()
        XCTAssertTrue(app.buttons["filter.apply"].waitForExistence(timeout: 3))
        app.buttons["filter.0.1"].tap(); app.buttons["filter.1.1"].tap()
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Search-Filters"; image.lifetime = .keepAlways; add(image)
        app.buttons["filter.apply"].tap()
        app.buttons["action.D02.@filters"].tap()
        XCTAssertTrue(app.buttons["filter.0.1"].isSelected)
        XCTAssertTrue(app.buttons["filter.1.1"].isSelected)
        app.buttons["filter.0.3"].tap()
        app.otherElements["search.filters"].swipeDown()
        app.buttons["action.D02.@filters"].tap()
        XCTAssertTrue(app.buttons["filter.0.1"].isSelected)
        app.buttons["filter.0.3"].tap(); app.buttons["filter.apply"].tap()
        XCTAssertTrue(app.staticTexts["No matches yet"].waitForExistence(timeout: 3))
        app.buttons["action.D02.@filters"].tap()
        app.buttons["filter.0.0"].tap(); app.buttons["filter.1.0"].tap(); app.buttons["filter.apply"].tap()
        XCTAssertFalse(app.staticTexts["No matches yet"].exists)
    }
    func testDetailActionsStayFixedWhileScrolling() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-state", "--screen", "D04"]
        app.launch()
        let start = app.buttons["action.D04.M02"]
        XCTAssertTrue(start.waitForExistence(timeout: 5)); XCTAssertTrue(start.isHittable)
        let initialY = start.frame.minY
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertEqual(start.frame.minY, initialY, accuracy: 1)
        XCTAssertTrue(start.isHittable)
        start.tap()
        let create = app.buttons["action.M02.@createProject"]
        XCTAssertTrue(create.waitForExistence(timeout: 3)); XCTAssertTrue(create.isHittable)
        let field = app.textFields["input.name"]
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertLessThanOrEqual(create.frame.maxY, app.keyboards.firstMatch.frame.minY)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Fixed-actions-keyboard"; shot.lifetime = .keepAlways; add(shot)
    }
    func testSearchDesignedResultsAndDetail() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset-test-state", "--screen", "D02"]; app.launch()
        XCTAssertTrue(app.buttons["search.open.D04"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["4 results"].exists)
        app.buttons["search.category.1"].tap()
        app.buttons["search.save.D04"].tap()
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Search-Page"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["search.open.D04"].tap()
        XCTAssertTrue(app.otherElements["screen.D04"].waitForExistence(timeout: 3))
        app.buttons["navigation.back"].tap()
        XCTAssertTrue(app.buttons["search.category.1"].isSelected)
    }
    func testMakingPagesAndPreviousDoesNotEraseProgress() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset-test-state", "--screen", "M02"]; app.launch()
        func capture(_ name: String) { let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot) }
        capture("Make-M02")
        app.buttons["action.M02.@createProject"].tap()
        XCTAssertTrue(app.otherElements["screen.M03"].waitForExistence(timeout: 3)); capture("Make-M03")
        app.buttons["action.M03.@projectMenu"].tap(); app.buttons["dialog.action.Edit project"].tap()
        XCTAssertTrue(app.otherElements["screen.M07"].waitForExistence(timeout: 3)); capture("Make-M07")
        app.buttons["action.M07.@editProject"].tap()
        app.buttons["action.M03.M04"].tap(); app.buttons["action.M04.@advance"].tap()
        app.buttons["action.M04.@previousStep"].tap()
        XCTAssertTrue(app.buttons["Next step"].exists)
        app.buttons["navigation.back"].tap()
        XCTAssertTrue(app.staticTexts["1 of 6 steps · In progress"].exists)
        app.buttons["action.M03.M04"].tap(); capture("Make-M04")
        tap(app.buttons["action.M04.M06"], in: app); capture("Make-M06")
        app.buttons["navigation.back"].tap()
        for _ in 1..<6 { app.buttons["action.M04.@advance"].tap() }
        XCTAssertTrue(app.otherElements["screen.M05"].waitForExistence(timeout: 3)); capture("Make-M05")
    }
    func testLanguageSwitchPersistsAndUpdatesNavigation() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset-test-state", "--screen", "P05"]; app.launch()
        let control = app.segmentedControls["settings.language"]
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        control.buttons.element(boundBy: 0).tap()
        XCTAssertEqual(app.buttons["action.P05.P08"].label, "\u{8d26}\u{53f7}")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Language-Chinese"; shot.lifetime = .keepAlways; add(shot)
        app.terminate(); app.launchArguments = ["--uitesting", "--screen", "P05"]; app.launch()
        XCTAssertTrue(app.segmentedControls["settings.language"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["settings.language"].buttons.element(boundBy: 0).isSelected)
        app.buttons["navigation.back"].tap()
        XCTAssertEqual(app.buttons["tab.P01"].label, "\u{6211}\u{7684}")
        app.terminate(); app.launchArguments = ["--uitesting", "--screen", "P05"]; app.launch()
        app.segmentedControls["settings.language"].buttons.element(boundBy: 1).tap()
        XCTAssertEqual(app.buttons["action.P05.P08"].label, "Account")
    }
    func testDesignedCommentsAndLocalReply() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset-test-state", "--screen", "C04"]; app.launch()
        let input = app.textFields["input.comment"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["5 comments"].exists)
        XCTAssertTrue(app.staticTexts["Author"].firstMatch.exists)
        let initialY = input.frame.minY
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Comments-Layout"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["comment.like.tessa"].tap()
        XCTAssertEqual(app.buttons["comment.like.tessa"].label, "Unlike comment, 13")
        app.buttons["comment.reply.tessa"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertLessThan(input.frame.maxY, app.keyboards.firstMatch.frame.minY)
        input.typeText("A lovely idea")
        app.buttons["comment.send"].tap()
        XCTAssertTrue(app.staticTexts["A lovely idea"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["A lovely idea"].isHittable)
        XCTAssertFalse(app.staticTexts["Local draft · Not published"].exists)
        XCTAssertEqual(input.frame.minY, initialY, accuracy: 1)
        app.terminate(); app.launchArguments = ["--uitesting", "--screen", "C04"]; app.launch()
        tap(app.staticTexts["A lovely idea"], in: app)
        XCTAssertTrue(app.staticTexts["A lovely idea"].exists)
    }
    func testCreatorLayoutAndIndependentFollowing() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset-test-state", "--screen", "C05"]; app.launch()
        XCTAssertTrue(app.buttons["creator.follow.Nora"].waitForExistence(timeout: 5))
        app.buttons["creator.follow.Nora"].tap()
        XCTAssertEqual(app.buttons["creator.follow.Nora"].label, "Following")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Creator"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["creator.stat.1"].tap()
        XCTAssertTrue(app.buttons["creator.follow.Tessa Kim"].waitForExistence(timeout: 3))
        app.buttons["creator.follow.Tessa Kim"].tap()
        XCTAssertEqual(app.buttons["creator.follow.Tessa Kim"].label, "Following")
        XCTAssertEqual(app.buttons["creator.follow.Elena Cruz"].label, "Follow")
        let list = XCTAttachment(screenshot: app.screenshot()); list.name = "Connections"; list.lifetime = .keepAlways; add(list)
        app.buttons["creator.tab.1"].tap()
        XCTAssertTrue(app.buttons["creator.tab.1"].isSelected)
        app.buttons["navigation.back"].tap()
        XCTAssertEqual(app.buttons["creator.follow.Nora"].label, "Following")
    }
    func testChineseCoverageAcrossFeatureScreens() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset-test-state", "--screen", "P05"]; app.launch()
        app.segmentedControls["settings.language"].buttons.element(boundBy: 0).tap()
        for (screen, expected) in [("C05", "粉丝"), ("C06", "粉丝（2.46 万）"), ("D04", "概览"), ("P03", "今天"), ("P04", "✓  用户名格式正确"), ("M02", "开始新项目"), ("X03", "当前离线。"), ("C04", "5 条评论")] {
            app.terminate(); app.launchArguments = ["--uitesting", "--screen", screen]; app.launch()
            XCTAssertTrue(app.staticTexts[expected].firstMatch.waitForExistence(timeout: 4) || app.buttons[expected].firstMatch.exists, screen)
            let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Chinese-" + screen; shot.lifetime = .keepAlways; add(shot)
        }
        app.terminate(); app.launchArguments = ["--uitesting", "--screen", "P05"]; app.launch()
        app.segmentedControls["settings.language"].buttons.element(boundBy: 1).tap()
    }
    func testTabsAndProjectCreation() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-state"]
        app.launch()
        XCTAssertTrue(app.otherElements["screen.D01"].waitForExistence(timeout: 10))
        app.buttons["tab.M01"].tap()
        let emptyShot = XCTAttachment(screenshot: app.screenshot()); emptyShot.name = "Make-Empty"; emptyShot.lifetime = .keepAlways; add(emptyShot)
        XCTAssertTrue(app.otherElements["screen.X02"].waitForExistence(timeout: 3))
        let create = app.buttons["action.X02.M02"]
        if !create.isHittable { app.swipeUp() }
        create.tap()
        XCTAssertTrue(app.textFields["input.name"].waitForExistence(timeout: 3))
        app.swipeUp()
        tap(app.buttons["action.M02.@createProject"], in: app)
        XCTAssertTrue(app.otherElements["screen.M03"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["tab.M01"].isHittable)
        app.buttons["navigation.back"].tap()
        XCTAssertTrue(app.otherElements["screen.M01"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["tab.M01"].isHittable)
        let makeShot = XCTAttachment(screenshot: app.screenshot()); makeShot.name = "Make-Home"; makeShot.lifetime = .keepAlways; add(makeShot)
        app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'project.'")).firstMatch.tap()
        tap(app.buttons["action.M03.M04"], in: app)
        for step in 0..<6 {
            tap(app.buttons["action.M04.@advance"], in: app)
            if step < 5 { XCTAssertTrue(app.buttons["action.M04.@advance"].exists) }
        }
        XCTAssertTrue(app.otherElements["screen.M05"].waitForExistence(timeout: 3))
        tap(app.buttons["action.M05.@place"], in: app)
        XCTAssertTrue(app.staticTexts["Added to your space"].waitForExistence(timeout: 3))
        app.buttons["dialog.action.OK"].tap()
        XCTAssertTrue(app.otherElements["screen.S02"].exists)
        app.buttons["navigation.back"].tap()
        XCTAssertTrue(app.otherElements["screen.S01"].waitForExistence(timeout:3))
        XCTAssertTrue(app.buttons["tab.S01"].isSelected)
        app.buttons["tab.M01"].tap()
        XCTAssertTrue(app.otherElements["screen.M01"].waitForExistence(timeout:3))
        XCTAssertTrue(app.buttons["tab.M01"].isHittable)
    }
    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<4 { if element.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(element.isHittable); element.tap()
    }
    func testDesignLayoutSmokeCoverage() {
        let app = XCUIApplication()
        let ids = (1...4).map { String(format: "D%02d", $0) } + (1...7).map { String(format: "M%02d", $0) } + (1...5).map { String(format: "S%02d", $0) } + (1...13).map { String(format: "C%02d", $0) } + (1...11).map { String(format: "P%02d", $0) } + (1...3).map { String(format: "A%02d", $0) } + (1...13).map { String(format: "X%02d", $0) }
        for id in ids {
            app.launchArguments = ["--uitesting", "--screen", id]
            app.launch()
            XCTAssertTrue(app.otherElements["screen.\(id)"].waitForExistence(timeout: 10), id)
            if ["D01","M01","S01","C01","P01"].contains(id) {
                XCTAssertTrue(app.buttons["tab.\(id)"].isHittable,id)
                XCTAssertFalse(app.buttons["navigation.back"].exists,id)
            } else {
                XCTAssertTrue(app.buttons["navigation.back"].isHittable,id)
                XCTAssertFalse(app.buttons["tab.D01"].isHittable,id)
            }
            let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = id; attachment.lifetime = .keepAlways; add(attachment)
            app.terminate()
        }
    }
    func testNativeEditablePostAndNoFakePublication() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--screen", "C02"]
        app.launch()
        XCTAssertTrue(app.textFields["input.title"].waitForExistence(timeout: 10))
        app.swipeUp()
        let draft = app.buttons["action.C02.@draft"]
        XCTAssertTrue(draft.waitForExistence(timeout: 3))
        tap(draft, in: app)
        XCTAssertTrue(app.staticTexts["Draft saved"].waitForExistence(timeout: 3))
    }
    func testLocalListsAndEditedProfile() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--screen", "P04"]
        app.launch()
        let name = app.textFields["input.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        if app.buttons["Clear text"].exists { app.buttons["Clear text"].tap() }
        name.typeText("Alex")
        app.keyboards.buttons["Done"].tap()
        tap(app.buttons["action.P04.@profile"], in: app)
        app.buttons["tab.P01"].tap()
        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
        tap(app.buttons["action.P01.P02"],in:app)
        XCTAssertTrue(app.buttons["saved.filter.All"].waitForExistence(timeout:3))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "P02-local"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testCreateAndRenameSpace() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-state", "--screen", "S01"]
        app.launch()
        XCTAssertTrue(app.buttons["space.create"].waitForExistence(timeout: 10))
        app.buttons["space.create"].tap()
        let name = app.textFields["input.space"]
        XCTAssertTrue(name.waitForExistence(timeout: 3)); name.tap(); name.typeText("Studio")
        app.keyboards.buttons["Done"].tap()
        tap(app.buttons["action.S03.@saveSpace"], in: app)
        XCTAssertTrue(app.staticTexts["Studio"].waitForExistence(timeout: 3))
        tap(app.buttons["action.S02.S03"], in: app)
        XCTAssertTrue(name.waitForExistence(timeout: 3)); name.tap()
        if app.buttons["Clear text"].exists { app.buttons["Clear text"].tap() }
        name.typeText("Studio two"); app.keyboards.buttons["Done"].tap()
        tap(app.buttons["action.S03.@saveSpace"], in: app)
        XCTAssertTrue(app.staticTexts["Studio two"].waitForExistence(timeout: 3))
        app.buttons["navigation.back"].tap()
        XCTAssertTrue(app.otherElements["screen.S01"].waitForExistence(timeout:3))
        XCTAssertTrue(app.buttons["tab.S01"].isHittable)
    }

    func testSearchNavigationAndEdgeSwipeRestoreTabBar() {
        let app=XCUIApplication();app.launchArguments=["--uitesting","--reset-test-state"];app.launch()
        app.buttons["action.D01.D02"].tap()
        let query=app.textFields["input.query"]
        XCTAssertTrue(query.waitForExistence(timeout:3));query.tap();query.typeText("weaving")
        app.keyboards.buttons["Search"].tap()
        XCTAssertEqual(query.value as? String,"weaving")
        XCTAssertFalse(app.buttons["tab.D01"].isHittable)
        app.buttons["navigation.back"].tap()
        XCTAssertTrue(app.otherElements["screen.D01"].waitForExistence(timeout:3))
        XCTAssertTrue(app.buttons["tab.D01"].isHittable)
        app.buttons["action.D01.P03"].tap()
        XCTAssertTrue(app.otherElements["screen.P03"].waitForExistence(timeout:3))
        let start=app.coordinate(withNormalizedOffset:CGVector(dx:0.01,dy:0.5))
        let end=app.coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:0.5))
        start.press(forDuration:0.05,thenDragTo:end)
        XCTAssertTrue(app.otherElements["screen.D01"].waitForExistence(timeout:3))
        XCTAssertTrue(app.buttons["tab.D01"].isHittable)
        for id in ["P01","C01","S01","D01"] {
            app.buttons["tab.\(id)"].tap()
            XCTAssertTrue(app.otherElements["screen.\(id)"].waitForExistence(timeout:3))
            XCTAssertTrue(app.buttons["tab.\(id)"].isSelected)
        }
    }
    func testUnsubmittedFormSurvivesRelatedPageRoundTrip() {
        let app=XCUIApplication();app.launchArguments=["--uitesting","--reset-test-state","--screen","C02"];app.launch()
        let title=app.textFields["input.title"]
        XCTAssertTrue(title.waitForExistence(timeout:5));title.tap()
        if app.buttons["Clear text"].exists {app.buttons["Clear text"].tap()}
        title.typeText("Keep this unsaved title");app.keyboards.buttons["Done"].tap()
        tap(app.buttons["action.C02.C05"],in:app)
        XCTAssertTrue(app.otherElements["screen.C05"].waitForExistence(timeout:3))
        app.buttons["navigation.back"].tap()
        XCTAssertTrue(app.otherElements["screen.C02"].waitForExistence(timeout:3))
        XCTAssertEqual(title.value as? String,"Keep this unsaved title")
    }

    func testTabIconStatesAndTouchTargets() {
        let app=XCUIApplication();app.launchArguments=["--uitesting","--reset-test-state"];app.launch()
        let ids=["D01","M01","S01","C01","P01"]
        for id in ids {
            app.buttons["tab.\(id)"].tap()
            let screen=id == "M01" ? "X02" : id
            XCTAssertTrue(app.otherElements["screen.\(screen)"].waitForExistence(timeout:3))
            for candidate in ids {
                let button=app.buttons["tab.\(candidate)"]
                XCTAssertTrue(button.isHittable)
                XCTAssertEqual(button.isSelected,candidate == id)
                XCTAssertGreaterThanOrEqual(button.frame.height,44)
            }
            let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Tab-\(id)";shot.lifetime = .keepAlways;add(shot)
        }
    }

    func testProfileDesignStructureAndLocalInteractions() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--uitesting","--reset-test-state","--screen","P01"];app.launch()
        XCTAssertTrue(app.images["profile.cover"].waitForExistence(timeout:4))
        XCTAssertTrue(app.buttons["profile.section.Makes"].exists)
        app.buttons["profile.section.Spaces"].tap()
        XCTAssertTrue(app.buttons["profile.space.Reading corner"].exists)
        app.buttons["profile.section.Drafts"].tap()
        XCTAssertTrue(app.buttons["profile.newDraft"].exists)
        app.buttons["profile.section.Makes"].tap()
        tap(app.buttons["action.P01.P02"],in:app)
        XCTAssertTrue(app.buttons["saved.filter.All"].waitForExistence(timeout:3))
        app.buttons["saved.filter.Tutorials"].tap()
        XCTAssertTrue(app.buttons["saved.collection.Weekend makes"].exists)
        XCTAssertFalse(app.buttons["saved.collection.Reading corner"].exists)
        app.buttons["saved.filter.All"].tap()
        tap(app.buttons["action.P02.P10"],in:app)
        let name=app.textFields["input.collection"];name.tap();name.typeText("Weekend ideas");app.keyboards.buttons["Done"].tap()
        tap(app.buttons["action.P10.@collection"],in:app)
        XCTAssertTrue(app.otherElements["screen.P02"].waitForExistence(timeout:3))
        app.terminate();app.launchArguments=["--uitesting","--screen","P03"];app.launch()
        let follow=app.buttons["activity.follow.tessa"]
        XCTAssertTrue(follow.waitForExistence(timeout:3));follow.tap();XCTAssertEqual(follow.label,"Following")
        app.buttons["activity.lena"].tap()
        XCTAssertTrue(app.otherElements["screen.C04"].waitForExistence(timeout:3))
        app.buttons["navigation.back"].tap();XCTAssertTrue(app.otherElements["screen.P03"].waitForExistence(timeout:3))
    }
    func testProfileDesignScreenshots() {
        let app=XCUIApplication()
        for id in ["P01","P02","P03","P04"] {
            app.launchArguments=["--uitesting","--reset-test-state","--screen",id];app.launch()
            XCTAssertTrue(app.otherElements["screen.\(id)"].waitForExistence(timeout:5))
            let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Profile-\(id)";shot.lifetime = .keepAlways;add(shot)
            app.swipeUp()
            let lower=XCTAttachment(screenshot:app.screenshot());lower.name="Profile-\(id)-scrolled";lower.lifetime = .keepAlways;add(lower);app.terminate()
        }
    }

    func testProfileUsernameAndLocationSaveAndReload() {
        let app=XCUIApplication();app.launchArguments=["--uitesting","--reset-test-state","--screen","P04"];app.launch()
        let username=app.textFields["input.username"]
        XCTAssertTrue(username.waitForExistence(timeout:5));username.tap();app.buttons["Clear text"].tap();username.typeText("maya.design");app.keyboards.buttons["Done"].tap()
        let location=app.textFields["input.location"];tap(location,in:app);location.typeText("Taipei");app.keyboards.buttons["Done"].tap()
        let save=app.buttons["action.P04.@profile"];XCTAssertTrue(save.isHittable);save.tap()
        app.terminate();app.launchArguments=["--uitesting","--screen","P04"];app.launch()
        XCTAssertTrue(username.waitForExistence(timeout:5));XCTAssertEqual(username.value as? String,"maya.design")
        XCTAssertEqual(location.value as? String,"Taipei")
    }

}
