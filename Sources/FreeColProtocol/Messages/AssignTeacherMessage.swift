import Foundation

public struct AssignTeacherMessage: FreeColMessage {
    public static let tag = "assignTeacher"

    public let student: String?
    public let teacher: String?

    public init(
        student: String? = nil,
        teacher: String? = nil
    ) {
        self.student = student
        self.teacher = teacher
    }

    public init(attributes: Attributes, children: Children) throws {
        self.student = attributes["student"]
        self.teacher = attributes["teacher"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = student { attrs["student"] = v }
        if let v = teacher { attrs["teacher"] = v }
        return (attrs, [])
    }
}
