/// The diplomatic tension level derived from a native settlement's alarm value.
///
/// These thresholds match FreeCol's `Tension.Level` values. Alarm is stored per
/// native settlement and European player; it is not a percentage.
public enum NativeAlarmLevel: Equatable, Sendable {
    case happy
    case content
    case displeased
    case angry
    case hateful

    public init(value: Int) {
        switch value {
        case ...100:
            self = .happy
        case ...600:
            self = .content
        case ...700:
            self = .displeased
        case ...800:
            self = .angry
        default:
            self = .hateful
        }
    }

    public var isHostile: Bool {
        self == .angry || self == .hateful
    }
}
