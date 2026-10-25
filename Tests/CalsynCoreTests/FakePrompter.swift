@testable import CalsynCore

final class FakePrompter: Prompter {
    private var answers: [() throws -> String]
    private(set) var questions: [String] = []

    init(_ answers: [() throws -> String] = []) {
        self.answers = answers
    }

    func ask(_ question: String) -> String? {
        questions.append(question)
        guard !answers.isEmpty else {
            return nil
        }
        return (try? answers.removeFirst()()) ?? ""
    }
}
