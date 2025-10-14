//
//  QuizViewModel.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import Foundation

@MainActor
final class QuizViewModel: ObservableObject {
    @Published private(set) var questions: [QuizQuestion]
    @Published private var selections: [String: Set<String>] = [:]
    @Published private(set) var selectedPhotoData: Data?

    init() {
        questions = QuizRepository.makeQuestionBank()
    }

    func isSelected(option: QuizOption, for question: QuizQuestion) -> Bool {
        selections[question.id]?.contains(option.id) ?? false
    }

    func toggle(option: QuizOption, for question: QuizQuestion) {
        switch question.type {
        case .singleChoice:
            selections[question.id] = [option.id]
        case .multiChoice:
            var set = selections[question.id] ?? []
            if set.contains(option.id) {
                set.remove(option.id)
            } else {
                set.insert(option.id)
            }
            selections[question.id] = set
        case .fileUpload:
            break
        }
    }

    func setPhotoData(_ data: Data?) {
        selectedPhotoData = data
    }

    func question(at index: Int) -> QuizQuestion {
        questions[index]
    }

    var totalQuestions: Int {
        questions.count
    }

    func resetSelections() {
        selections.removeAll()
        selectedPhotoData = nil
    }

    var isComplete: Bool {
        for question in questions where !question.isOptional && question.type != .fileUpload {
            let selection = selections[question.id] ?? []
            if selection.isEmpty {
                return false
            }
        }
        return true
    }

    func buildResult() -> QuizResult {
        let answerDictionary = selections.mapValues { Array($0) }
        return QuizResult(answers: answerDictionary, selectedPhoto: selectedPhotoData)
    }
}
