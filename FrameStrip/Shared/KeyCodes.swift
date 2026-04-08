import Carbon.HIToolbox

enum KeyCodes {
    static let escape: UInt16 = UInt16(kVK_Escape)
    static let returnKey: UInt16 = UInt16(kVK_Return)
    static let leftArrow: UInt16 = UInt16(kVK_LeftArrow)
    static let rightArrow: UInt16 = UInt16(kVK_RightArrow)
    static let downArrow: UInt16 = UInt16(kVK_DownArrow)
    static let upArrow: UInt16 = UInt16(kVK_UpArrow)

    static let displayNames: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H",
        5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3",
        21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]",
        31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "↩", 37: "L", 38: "J", 39: "'", 40: "K",
        41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
        46: "M", 47: ".", 48: "⇥", 49: "Space",
        50: "`", 51: "⌫", 53: "⎋",
        96: "F5", 97: "F6", 98: "F7", 99: "F3",
        100: "F8", 101: "F9", 103: "F11", 105: "F13",
        107: "F14", 109: "F10", 111: "F12", 113: "F15",
        115: "Home", 116: "⇞", 117: "⌦", 118: "F4",
        119: "End", 120: "F2", 121: "⇟", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}
