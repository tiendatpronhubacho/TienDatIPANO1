import Foundation

enum ExploitSupportPolicy {
    static let verifiedIOS17Range = "17.0–17.7.x"
    static let verifiedIOS18Range = "18.0–18.7.1"
    static let verifiedIOS26BadQueryRange = "26.0–26.6.1"
    static let verifiedIOS26WorseQueryRange = "26.7–26.7.2"
    static let verifiedIOS27Range = "27.0–27.2"
    
    static func supportsKernelExploit(major: Int, minor: Int, patch: Int, isA10: Bool = false) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }

        // A10 Fusion devices can hang in the iOS 17 kernel chain. Keep the
        // general iOS 17 range, but refuse this specific chipset safely.
        if isA10 && major == 17 { return false }

        if major == 17 {
            return minor <= 7
        }

        if major == 18 {
            return minor < 7 || (minor == 7 && patch <= 1)
        }

        return false
    }

    static func supportsBadQuery(major: Int, minor: Int, patch: Int) -> Bool {
        guard major == 26, minor >= 0, patch >= 0 else { return false }
        return minor < 6 || (minor == 6 && patch <= 1)
    }

    static func supportsWorseQuery(major: Int, minor: Int, patch: Int) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }
        if major == 26 {
            // Only iOS 26.7.0–26.7.2. iOS 26.6.2 is intentionally excluded.
            return minor == 7 && patch <= 2
        }
        if major == 27 {
            // iOS 27.0.x–27.1.x and 27.2.0; 27.2.1+ is excluded.
            return minor < 2 || (minor == 2 && patch == 0)
        }
        return false
    }

    static func isExperimental(major: Int, minor: Int) -> Bool {
        false
    }

    static func isSupported(major: Int, minor: Int, patch: Int, build: String, isA10: Bool = false) -> Bool {
        if supportsKernelExploit(major: major, minor: minor, patch: patch, isA10: isA10) { return true }
        if supportsBadQuery(major: major, minor: minor, patch: patch) { return true }
        if supportsWorseQuery(major: major, minor: minor, patch: patch) { return true }
        return isExperimental(major: major, minor: minor)
    }
}