import Foundation

public protocol Prompter {
    func ask(_ question: String) -> String?
}

public struct StdinPrompter: Prompter {
    public init() {}

    public func ask(_ question: String) -> String? {
        print(question, terminator: " ")
        fflush(stdout)
        return readLine()
    }
}
