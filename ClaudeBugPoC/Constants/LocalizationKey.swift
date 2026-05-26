//
//  LocalizationKey.swift
//  ClaudeBugPoC
//

import Foundation

enum LocalizationKey {

    enum Tab {
        static let pokemon = "tabs.main.pokemon"
        static let meals = "tabs.main.meals"
        static let countries = "tabs.main.countries"
        static let launches = "tabs.main.launches"
        static let testDetay = "tabs.main.testDetay"
    }

    enum View {

        enum Common {
            static let errorAlertTitle = "common.alert.error.title"
            static let okButton = "common.alert.ok"
        }

        enum AIAssistant {
            static let title = "aiAssistant.title"
            static let accessibilityLabel = "aiAssistant.accessibilityLabel"
            static let menuContact = "aiAssistant.menu.contact"
            static let menuInspect = "aiAssistant.menu.inspect"
            static let menuFigmaCompare = "aiAssistant.menu.figmaCompare"
        }

        enum FigmaCompare {
            static let navigationTitle = "figmaCompare.navigationTitle"
            static let urlInputTitle = "figmaCompare.urlInput.title"
            static let urlInputSubtitle = "figmaCompare.urlInput.subtitle"
            static let urlInputPlaceholder = "figmaCompare.urlInput.placeholder"
            static let submitButton = "figmaCompare.button.submit"
            static let cancelButton = "figmaCompare.button.cancel"
            static let loadingMessage = "figmaCompare.loading.message"
            static let resultTitle = "figmaCompare.result.title"
            static let resultEmpty = "figmaCompare.result.empty"
            static let errorInvalidURL = "figmaCompare.error.invalidURL"
            static let errorFormat = "figmaCompare.error.format"
            static let unexpectedResponse = "figmaCompare.error.unexpectedResponse"
            static let detectedScreenFormat = "figmaCompare.detectedScreen.format"
            static let metadataFormat = "figmaCompare.metadata.format"
            static let categoryLayout = "figmaCompare.category.layout"
            static let categoryColor = "figmaCompare.category.color"
            static let categoryTypography = "figmaCompare.category.typography"
            static let categorySpacing = "figmaCompare.category.spacing"
            static let categoryMissing = "figmaCompare.category.missing"
            static let categoryExtra = "figmaCompare.category.extra"
            static let categoryIcons = "figmaCompare.category.icons"
            static let categoryOther = "figmaCompare.category.other"
            static let severityHigh = "figmaCompare.severity.high"
            static let severityMedium = "figmaCompare.severity.medium"
            static let severityLow = "figmaCompare.severity.low"
            static let editButton = "figmaCompare.button.edit"
            static let createJiraButton = "figmaCompare.button.createJira"
            static let openButton = "figmaCompare.button.open"
            static let creatingJiraMessage = "figmaCompare.action.creatingJira"
            static let applyingFixMessage = "figmaCompare.action.applyingFix"
            static let jiraSuccessTitle = "figmaCompare.action.jiraSuccess.title"
            static let jiraSuccessMessage = "figmaCompare.action.jiraSuccess.message"
            static let fixSuccessTitle = "figmaCompare.action.fixSuccess.title"
            static let fixSuccessMessage = "figmaCompare.action.fixSuccess.message"
        }

        enum AIInspector {
            static let title = "aiInspector.title"
            static let hint = "aiInspector.hint"
            static let close = "aiInspector.close"
            static let localizationKeyLabel = "aiInspector.localizationKey.label"
            static let backendValueLabel = "aiInspector.backendValue.label"
            static let emptyText = "aiInspector.emptyText"
        }

        // swiftlint:disable:next type_body_length
        enum AIChat {
            static let navigationTitle = "aiChat.navigationTitle"
            static let welcomeMessage = "aiChat.welcome.message"
            static let inputPlaceholder = "aiChat.input.placeholder"
            static let sendButton = "aiChat.button.send"
            static let createPRButton = "aiChat.button.createPR"
            static let noChangesApproved = "aiChat.message.noChangesApproved"
            static let describeBugFirst = "aiChat.message.describeBugFirst"
            static let errorFormat = "aiChat.message.error.format"
            static let unexpectedResponse = "aiChat.message.unexpectedResponse"
            static let noResponse = "aiChat.message.noResponse"
            static let metadataFormat = "aiChat.message.metadata.format"
            static let cacheMetadata = "aiChat.message.metadata.cache"
            static let technicalSeparator = "aiChat.message.technicalSeparator"
            static let noCodeChange = "aiChat.message.noCodeChange"
            static let technicalDetailFormat = "aiChat.message.technicalDetail.format"
            static let jiraError = "aiChat.message.jiraError.format"
            static let jiraInvalidResponse = "aiChat.message.jiraInvalidResponse"
            static let sprintAdded = "aiChat.message.sprintAdded.format"
            static let prError = "aiChat.message.prError.format"
            static let prInvalidResponse = "aiChat.message.prInvalidResponse"
            static let prOpened = "aiChat.message.prOpened.format"
            static let diffNoChanges = "aiChat.diff.noChanges"
            static let roleUser = "aiChat.role.user"
            static let roleAssistant = "aiChat.role.assistant"
            static let roleSystem = "aiChat.role.system"
            static let proposedChangeHeader = "aiChat.proposedChange.header"
            static let acceptChange = "aiChat.proposedChange.accept"
            static let rejectChange = "aiChat.proposedChange.reject"
            static let acceptedChange = "aiChat.proposedChange.accepted"
            static let rejectedChange = "aiChat.proposedChange.rejected"
            static let actionPrompt = "aiChat.action.prompt"
            static let bugActionTitle = "aiChat.action.bug.title"
            static let bugActionSubtitle = "aiChat.action.bug.subtitle"
            static let codeActionTitle = "aiChat.action.code.title"
            static let codeActionSubtitle = "aiChat.action.code.subtitle"
            static let jiraCreating = "aiChat.jira.creating"
            static let jiraCreated = "aiChat.jira.created"
            static let jiraNoChangeSuffix = "aiChat.jira.noChangeSuffix"
            static let jiraChangesBelowSuffix = "aiChat.jira.changesBelowSuffix"
            static let jiraTicketHeader = "aiChat.jira.ticketHeader"
            static let openJira = "aiChat.jira.openButton"
        }

        enum Pokemon {
            static let height = "pokemon.detail.height"
            static let weight = "pokemon.detail.weight"
            static let stats = "pokemon.detail.stats"
        }

        enum Meals {
            static let youtube = "meals.detail.youtube"
            static let ingredients = "meals.detail.ingredients"
            static let instructions = "meals.detail.instructions"
            static let noInstructions = "meals.detail.noInstructions"
        }

        enum Countries {
            static let openMap = "countries.detail.openMap"
            static let capital = "countries.detail.capital"
            static let region = "countries.detail.region"
            static let population = "countries.detail.population"
            static let area = "countries.detail.area"
            static let languages = "countries.detail.languages"
            static let currency = "countries.detail.currency"
            static let timezone = "countries.detail.timezone"
            static let borders = "countries.detail.borders"
        }

        enum Launches {
            static let webcast = "launches.detail.webcast"
            static let article = "launches.detail.article"
            static let wikipedia = "launches.detail.wikipedia"
            static let flightFormat = "launches.detail.flight.format"
        }
    }
}
