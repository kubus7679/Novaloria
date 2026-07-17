import Foundation

public struct AssignTeacherMessage: FreeColMessage {
    public static let tag = "assignTeacher"

    public let teacher: String?
    public let student: String?

    public init(
        teacher: String? = nil,
        student: String? = nil
    ) {
        self.teacher = teacher
        self.student = student
    }

    public init(attributes: Attributes, children: Children) throws {
        self.teacher = attributes["teacher"]
        self.student = attributes["student"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = teacher { attrs["teacher"] = v }
        if let v = student { attrs["student"] = v }
        return (attrs, [])
    }
}
