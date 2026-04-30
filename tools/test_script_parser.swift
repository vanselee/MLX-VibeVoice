import Foundation

@main
struct ScriptParserTestRunner {
    static func main() {
        let bracket = ScriptParser.parse("""
        [旁白] 今天我们聊一个现实问题。
        [博主] 同一条视频为什么平台表现不同？
        """)
        expect(bracket.roles.map(\.normalizedName) == ["旁白", "博主"], "square bracket roles")
        expect(bracket.segments.map(\.roleName) == ["旁白", "博主"], "square bracket segments")
        expect(bracket.unmarkedSegmentCount == 0, "square bracket unmarked count")

        let chineseBracket = ScriptParser.parse("【客服】因为每个平台的审核逻辑不同。")
        expect(chineseBracket.roles.map(\.normalizedName) == ["客服"], "chinese bracket role")
        expect(chineseBracket.segments.first?.text == "因为每个平台的审核逻辑不同。", "chinese bracket text")

        let colon = ScriptParser.parse("""
        老板：今天先讲结果。
        客服: 再讲解决方案。
        """)
        expect(colon.roles.map(\.normalizedName) == ["老板", "客服"], "colon roles")
        expect(colon.segments.map(\.roleName) == ["老板", "客服"], "colon segments")

        let unmarked = ScriptParser.parse("""
        没有标记的这一行会自动当作旁白。
        [博主] 有标记的行保留角色。
        """)
        expect(unmarked.roles.map(\.normalizedName) == ["旁白", "博主"], "unmarked roles")
        expect(unmarked.segments[0].roleName == "旁白", "unmarked narrator fallback")
        expect(unmarked.segments[0].wasUnmarked, "unmarked flag")
        expect(unmarked.unmarkedSegmentCount == 1, "unmarked count")

        let empty = ScriptParser.parse("   \n\n")
        expect(empty.roles.map(\.normalizedName) == ["旁白"], "empty roles")
        expect(empty.segments.count == 1, "empty placeholder segment")
        expect(empty.unmarkedSegmentCount == 1, "empty unmarked count")

        print("ScriptParser tests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
