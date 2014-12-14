import std.array;
import std.stdio;

import yadc.peg;

/// メイン関数
void main() {
    // 改行文字
    alias ch!'\r' cr;
    alias ch!'\n' lf;

    // 改行
    alias addLine!(sel!(lf, seq!(cr, opt!(lf)))) newLine;

    // 空白。改行か空白文字のいずれか
    alias sel!(newLine, set!" \t\v\f") whiteSpace;

    // 単語
    alias more1!(seq!(not!whiteSpace, any)) word;

    // 単語カウントアクション
    size_t count = 0;
    alias action!(
        (s) {}, // 解析開始時
        (s) {++count;}, // 解析成功時
        (s) {}, // 解析失敗時
        word) wordCount;

    // 単語カウント解析処理全体のパーサー
    alias seq!(more0!(sel!(wordCount, whiteSpace)), end) parseText;

    // 標準入力を読み込む
    auto app = appender!(ubyte[])();
    ubyte[128] buffer = void;
    for(ubyte[] s; !(s = stdin.rawRead(buffer)).empty;) {
        app.put(s);
    }

    // 読み込んだ内容の解析
    auto src = textRange(app.data);
    auto result = parseText(src);

    // ふつう解析成功する
    assert(result);

    // 結果の出力。行数・単語数・バイト数
    writefln("%d %d %d", src.line, count, src.position);
}

