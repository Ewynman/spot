//
//  PermissionPrePromptStringsTests.swift
//  SpotTests
//
//  Regression tests for strings shown on Spot’s custom permission pre-prompts.
//  Apple App Review (Guideline 5.1.1) explicitly flagged earlier wording
//  ("Enable...", "Maybe Later") as inappropriate. These tests assert that
//  every user-facing string defined in `PermissionPrePromptStrings`:
//
//   * Uses neutral primary actions (`Continue` / `Open iOS Settings`).
//   * Avoids forbidden phrases like `Enable...`, `Allow Notifications`,
//     `Maybe Later`, `Required`, `Must enable`, `Turn On Notifications`.
//   * Keeps the secondary "Continue Without ..." escape hatch intact for
//     each of the four optional permissions.
//
//  Scope is intentionally limited to `PermissionPrePromptStrings.swift` —
//  the word `Enable` is fine in unrelated app contexts.
//

import Testing
@testable import Spot

struct PermissionPrePromptStringsTests {

    // MARK: - Primary buttons

    @Test func primaryButtonsAreNeutral() {
        #expect(PermissionPrePromptStrings.continueButton == "Continue")
        #expect(PermissionPrePromptStrings.openSettingsButton == "Open iOS Settings")
    }

    // MARK: - Secondary "Continue Without ..." escape hatches

    @Test func everyPromptHasContinueWithoutSecondary() {
        #expect(PermissionPrePromptStrings.Location.secondaryAction == "Continue Without Location")
        #expect(PermissionPrePromptStrings.Notifications.secondaryAction == "Continue Without Notifications")
        #expect(PermissionPrePromptStrings.Camera.secondaryAction == "Continue Without Camera")
        #expect(PermissionPrePromptStrings.Photos.secondaryAction == "Continue Without Photos")
    }

    // MARK: - Forbidden phrases must not appear anywhere

    @Test func noForbiddenPhrasesInAnyPromptCopy() {
        for copy in PermissionPrePromptStrings.allUserFacingStrings {
            for phrase in PermissionPrePromptStrings.forbiddenPhrases {
                #expect(
                    !copy.localizedCaseInsensitiveContains(phrase),
                    "Permission prompt copy must not contain forbidden phrase: \(phrase). Found in: \"\(copy)\""
                )
            }
        }
    }

    @Test func contextualPrePromptCopyAvoidsSkipStyleBypasses() {
        // PRD §10.3 / §11.3 / §12.5 / §13.5: the contextual pre-permission
        // screens that fire the native iOS dialog must not surface `Skip`
        // / `Not Now` / bare `Open Settings` as a primary action. The
        // longer `Open iOS Settings` form is allowed for denied recovery.
        let bypassPhrases = ["Skip ", "Not Now", "Open Settings"]
        for copy in PermissionPrePromptStrings.allUserFacingStrings {
            if copy == PermissionPrePromptStrings.openSettingsButton { continue }
            for phrase in bypassPhrases {
                #expect(
                    !copy.localizedCaseInsensitiveContains(phrase),
                    "Pre-prompt copy must not contain bypass phrase: \(phrase). Found in: \"\(copy)\""
                )
            }
        }
    }

    @Test func standalonePrimaryButtonAvoidsCoerciveLanguage() {
        // "Continue" should never be replaced by "Allow", "Enable", or
        // "Turn On" wording in the primary button helper.
        let primary = PermissionPrePromptStrings.continueButton
        #expect(!primary.localizedCaseInsensitiveContains("Allow"))
        #expect(!primary.localizedCaseInsensitiveContains("Enable"))
        #expect(!primary.localizedCaseInsensitiveContains("Turn On"))
    }

    // MARK: - Body copy explains optionality

    @Test func locationCopyMentionsExplorableMap() {
        #expect(PermissionPrePromptStrings.Location.body.localizedCaseInsensitiveContains("explore"))
    }

    @Test func notificationCopyMentionsOptional() {
        #expect(PermissionPrePromptStrings.Notifications.body.localizedCaseInsensitiveContains("optional"))
    }

    @Test func deniedCopyKeepsAppUsable() {
        #expect(PermissionPrePromptStrings.Location.deniedBody.localizedCaseInsensitiveContains("United States"))
        #expect(PermissionPrePromptStrings.Notifications.deniedBody.localizedCaseInsensitiveContains("normally"))
        #expect(PermissionPrePromptStrings.Camera.deniedBody.localizedCaseInsensitiveContains("without"))
        #expect(PermissionPrePromptStrings.Photos.deniedBody.localizedCaseInsensitiveContains("without"))
    }

    // MARK: - Titles avoid coercion

    @Test func titlesAreFeatureCenteredNotPermissionCentered() {
        // PRD §10.2 / §11.2 / §12.4 / §13.4: the title should describe
        // what the user is doing, not what they're being asked to enable.
        #expect(PermissionPrePromptStrings.Location.title == "Show nearby spots")
        #expect(PermissionPrePromptStrings.Notifications.title == "Stay updated")
        #expect(PermissionPrePromptStrings.Camera.title == "Take a photo")
        #expect(PermissionPrePromptStrings.Photos.title == "Choose a photo")

        for title in [
            PermissionPrePromptStrings.Location.title,
            PermissionPrePromptStrings.Notifications.title,
            PermissionPrePromptStrings.Camera.title,
            PermissionPrePromptStrings.Photos.title
        ] {
            #expect(!title.localizedCaseInsensitiveContains("Allow"))
            #expect(!title.localizedCaseInsensitiveContains("Enable"))
            #expect(!title.localizedCaseInsensitiveContains("Required"))
        }
    }

    // MARK: - Body copy describes the contextual, optional nature

    @Test func bodyCopyDescribesOptionalNature() {
        // PRD §12.4 / §13.4: location and notifications copy must reassure
        // users the app keeps working without those permissions.
        #expect(PermissionPrePromptStrings.Location.body
            .localizedCaseInsensitiveContains("without sharing your location"))
        #expect(PermissionPrePromptStrings.Notifications.body
            .localizedCaseInsensitiveContains("optional"))

        // PRD §10.2 / §11.2: photo and camera copy must describe the
        // contextual trigger — only when the user picks an image.
        #expect(PermissionPrePromptStrings.Photos.body
            .localizedCaseInsensitiveContains("only when you choose"))
        #expect(PermissionPrePromptStrings.Camera.body
            .localizedCaseInsensitiveContains("only when you choose"))
    }
}
