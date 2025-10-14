//
//  QuizModels.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import CoreData
import Foundation
import SwiftUI

enum QuizQuestionType {
    case singleChoice
    case multiChoice
    case fileUpload
}

struct QuizOption: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String?

    init(id: String, title: String, icon: String? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
    }
}

struct QuizQuestion: Identifiable {
    let id: String
    let prompt: String
    let type: QuizQuestionType
    let options: [QuizOption]
    let isOptional: Bool

    init(
        id: String,
        prompt: String,
        type: QuizQuestionType = .singleChoice,
        options: [QuizOption],
        isOptional: Bool = false
    ) {
        self.id = id
        self.prompt = prompt
        self.type = type
        self.options = options
        self.isOptional = isOptional
    }
}

struct QuizResult {
    var answers: [String: [String]]
    var selectedPhoto: Data?
    var userName: String?
    var age: Int?

    var primaryGoal: String? {
        answers["glow_motivation"]?.first
    }

    var preferredColorFamily: String? {
        answers["dream_palette"]?.first
    }

    var undertoneKnowledge: String? {
        answers["do_you_know_your_undertone"]?.first
    }

    var faceShapeConfidence: String? {
        answers["do_you_know_your_face_shape"]?.first
    }
}

extension QuizResult {
    init(from quiz: OnboardingQuiz) {
        if let stored = quiz.answers as? [String: [String]] {
            self.answers = stored
        } else if let stored = quiz.answers as? [String: String] {
            self.answers = stored.mapValues { [$0] }
        } else {
            self.answers = [:]
        }
        self.selectedPhoto = nil
        self.userName = quiz.value(forKey: "userName") as? String

        if let rawAge = quiz.value(forKey: "age") {
            if let number = rawAge as? NSNumber {
                let intValue = number.intValue
                self.age = intValue > 0 ? intValue : nil
            } else if let int16Value = rawAge as? Int16 {
                let intValue = Int(int16Value)
                self.age = intValue > 0 ? intValue : nil
            } else {
                self.age = nil
            }
        } else {
            self.age = nil
        }
    }
}

struct PaywallPreview {
    let headline: String
    let insightBullets: [String]
    let solutionBullets: [String]
}

enum QuizRepository {
    static func makeQuestionBank() -> [QuizQuestion] {
        [
            QuizQuestion(
                id: "mirror_focus",
                prompt: "What do you zero in on first when you face the mirror each morning?",
                options: [
                    QuizOption(id: "skin_texture", title: "Every tiny skin texture shift"),
                    QuizOption(id: "dark_circles", title: "The shadows under my eyes"),
                    QuizOption(id: "jawline_focus", title: "Jawline and cheek definition"),
                    QuizOption(id: "glow_check", title: "Overall glow—it changes daily")
                ]
            ),
            QuizQuestion(
                id: "candid_reaction",
                prompt: "When a friend tags you in a candid photo, you usually…",
                options: [
                    QuizOption(id: "hide_photo", title: "Hide it immediately—no one needs to see that"),
                    QuizOption(id: "ask_retake", title: "Beg for a retake and coach the next shot"),
                    QuizOption(id: "share_proud", title: "Share it proudly in the group chat"),
                    QuizOption(id: "shrug_off", title: "Shrug it off but replay it in my head later")
                ]
            ),
            QuizQuestion(
                id: "moment_avoid",
                prompt: "Which moment do you secretly dodge because cameras make it awkward?",
                options: [
                    QuizOption(id: "night_out", title: "Night out selfies with friends"),
                    QuizOption(id: "family_event", title: "Family gatherings and reunions"),
                    QuizOption(id: "first_dates", title: "First dates or new connections"),
                    QuizOption(id: "work_calls", title: "Work calls where the camera is always on")
                ]
            ),
            QuizQuestion(
                id: "style_block",
                prompt: "What keeps you from trying the looks you save on your mood board?",
                options: [
                    QuizOption(id: "no_guidance", title: "I have zero guidance on what suits me"),
                    QuizOption(id: "budget", title: "Budget anxiety—I can’t risk a miss"),
                    QuizOption(id: "time", title: "No time to test and experiment"),
                    QuizOption(id: "confidence_block", title: "Confidence crashes before I even start")
                ]
            ),
            QuizQuestion(
                id: "hype_circle",
                prompt: "Who hypes you up the loudest right now?",
                options: [
                    QuizOption(id: "best_friend", title: "My best friend who gets my vibe"),
                    QuizOption(id: "partner", title: "A partner who notices every glow-up"),
                    QuizOption(id: "self", title: "Honestly, just me finding the energy"),
                    QuizOption(id: "quiet", title: "No one really—it's way too quiet lately")
                ]
            ),
            QuizQuestion(
                id: "glow_motivation",
                prompt: "What are you craving most from this glow journey?",
                options: [
                    QuizOption(id: "photos", title: "Photos I actually want to post"),
                    QuizOption(id: "confidence", title: "Daily confidence that sticks"),
                    QuizOption(id: "clarity", title: "Clarity on what truly suits me"),
                    QuizOption(id: "reinvention", title: "A full reinvention—ready to shock them")
                ]
            ),
            QuizQuestion(
                id: "dream_palette",
                prompt: "Pick the color mood you wish loved you back every time.",
                options: [
                    QuizOption(id: "warm", title: "Molten golds and warm honey tones"),
                    QuizOption(id: "cool", title: "Icy lilacs and sapphire blues"),
                    QuizOption(id: "neutral", title: "Creamy neutrals and soft blushes"),
                    QuizOption(id: "no_clue", title: "No clue—teach me everything")
                ]
            )
        ]
    }
}
