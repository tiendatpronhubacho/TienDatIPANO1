import Foundation

enum ExploitSupportPolicy {
    static let verifiedIOS17Range = "17.0–17.7.x"
    static let verifiedIOS18Range = "18.0–18.7.1"
    static let verifiedIOS26BadQueryRange = "26.0–26.6.1"
    static let verifiedIOS26WorseQueryRange = "26.7–26.7.2"
    static let verifiedIOS27Range = "27.0–27.2"
    static let verifiedIOS27BuildGatedRange = "27.3 beta 1"
    static let verifiedIOS27Builds: [String] = ["24C5037i"]
    
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

    static func supportsWorseQuery(major: Int, minor: Int, patch: Int, build: String = "") -> Bool {
        guard minor >= 0, patch >= 0 else { return false }
        if major == 26 {
            // Only iOS 26.7.0–26.7.2. iOS 26.6.2 is intentionally excluded.
            return minor == 7 && patch <= 2
        }
        if major == 27 {
            // 3106 policy: every 27.0–27.2 build; 27.3 beta 1 only by exact build.
            if minor <= 2 { return true }
            if minor == 3 {
                return patch == 0 && verifiedIOS27Builds.contains(build)
            }
        }
        return false
    }

    static func isExperimental(major: Int, minor: Int) -> Bool {
        false
    }

    static func isSupported(major: Int, minor: Int, patch: Int, build: String, isA10: Bool = false) -> Bool {
        if supportsKernelExploit(major: major, minor: minor, patch: patch, isA10: isA10) { return true }
        if supportsBadQuery(major: major, minor: minor, patch: patch) { return true }
        if supportsWorseQuery(major: major, minor: minor, patch: patch, build: build) { return true }
        return isExperimental(major: major, minor: minor)
    }
}