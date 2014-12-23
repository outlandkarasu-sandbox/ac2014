module yadc.pegpeg;

import std.array : empty;

import yadc.peg;

import compile_time_unittest : enableCompileTimeUnittest;
mixin enableCompileTimeUnittest;

/// PEGノードの型
enum PegNode {
    STRING,   /// リテラル文字列
    CHAR,     /// リテラル文字
    ID,       /// 識別子
    ANY,      /// 任意の1文字
    RANGE,    /// 文字範囲
    SET,      /// 文字集合
    END,      /// 終端
    OPTION,   /// 有るか無いか
    AND,      /// 有るかテスト
    NOT,      /// 無いかテスト
    MORE0,    /// 0個以上
    MORE1,    /// 1個以上
    SELECT,   /// 選択
    SEQUENCE, /// 連接
    DEFINE,   /// 定義
    ROOT,     /// ルートノード
}

/// 改行
alias addLine!(sel!(seq!(ch!'\r', opt!(ch!'\n')), ch!'\n')) newLine;

/// 改行文字(改行チェック用)
alias set!"\r\n" newLineChars;

/// 空白
alias set!" \t\v\f" space;

/// 空白列
alias more1!(sel!(newLine, space)) whiteSpaces;

/// 8進数時
alias rng!('0', '7') octDigit;

/// 16進数時
alias sel!(rng!('0', '9'), rng!('a', 'f'), rng!('A', 'F')) hexDigit;

/// エスケープシーケンス文字
alias set!"\'\"\?\\abfnrtv0" escChars;

/// 16進数字エスケープシーケンス
alias seq!(ch!'x', hexDigit, hexDigit) hexEscape;

/// 8進数字エスケープシーケンス
alias seq!(octDigit, opt!octDigit, opt!octDigit) octEscape;

/// 16進数4文字
alias seq!(hexDigit, hexDigit, hexDigit, hexDigit) hex4Digit;

/// ユニコード16ビットエスケープシーケンス
alias seq!(ch!'u', hex4Digit) unicode16Escape;

/// ユニコード32ビットエスケープシーケンス
alias seq!(ch!'U', hex4Digit, hex4Digit) unicode32Escape;

/// エスケープシーケンス
alias seq!(ch!'\\', sel!(
    escChars,
    hexEscape,
    octEscape,
    unicode16Escape,
    unicode32Escape)) escapeSequence;

// エスケープシーケンスのテスト
unittest {
    auto escs = [
        `\r`, `\n`, `\t`, `\v`, `\f`, `\a`, `\b`, `\'`, `\"`, `\0`, `\\`, `\?`,
        `\x0F`, `\7`, `\77`, `\177`, `\u000a`, `\U000A000d`, ];
    foreach(s; escs) {
        auto src = s;
        assert(escapeSequence(src), s);
        assert(src.empty);
    }
}

/// シングルクオート
alias ch!'\'' quot;

/// ダブルクオート
alias ch!'\"' dquot;

/// 文字リテラル
alias seq!(quot, sel!(escapeSequence, seq!(not!quot, any)), quot) charLiteral;

// 文字リテラルのテスト
unittest {
    auto literals = [
        q{'\r'}, q{'\n'}, q{'\t'}, q{'\v'}, q{'\f'}, q{'\a'}, q{'\b'}, q{'\''}, q{'\"'}, q{'\0'}, q{'\\'}, q{'\?'},
        q{'\x0F'}, q{'\7'}, q{'\77'}, q{'\177'}, q{'\u000a'}, q{'\U000A000d'},
        q{' '}, q{'a'}, q{'0'}];
    foreach(s; literals) {
        auto src = s;
        assert(charLiteral(src), s);
        assert(src.empty, s);
    }

    auto notLiterals = [
        `'`, `''`, `'a`, `a'`, `'\\\\\\'`, `'a"`, `"a'`, `'\0000'`, `'\u00000'`, `'\U000000000'`,
        ];
    foreach(s; notLiterals) {
        auto src = s;
        assert(!charLiteral(src), s);
        assert(src == s, s);
    }
}

/// 文字列リテラル
alias seq!(dquot, more0!(sel!(escapeSequence, seq!(not!dquot, any))), dquot) stringLiteral;

// 文字列リテラルのテスト
unittest {
    auto literals = [
        q{"\r"}, q{"\n"}, q{"\t"}, q{"\v"}, q{"\f"}, q{"\a"}, q{"\b"}, q{"\""}, q{"\""}, q{"\0"}, q{"\\"}, q{"\?"},
        q{"\x0F"}, q{"\7"}, q{"\77"}, q{"\177"}, q{"\u000a"}, q{"\U000A000d"},
        q{" "}, q{"a"}, q{"0"},
        q{""}, q{"abcdefg"}, q{"\\\\\\\\\"\'\\"}, q{"0123456789"}];
    foreach(s; literals) {
        auto src = s;
        assert(stringLiteral(src), s);
        assert(src.empty, s);
    }

    auto notLiterals = [
        `"`, `"'`, `"\"`, `"test\"`
        ];
    foreach(s; notLiterals) {
        auto src = s;
        assert(!stringLiteral(src), s);
        assert(src == s, s);
    }
}

/// コメント
alias seq!(ch!'#', more0!(seq!(not!newLineChars, sel!(whiteSpaces, any))), sel!(newLine, end)) comment;

///
unittest {
    auto s = textRange("#");
    assert(comment(s));
    assert(s.position == 1);
    assert(s.line == 0);

    s = textRange("#\n");
    assert(comment(s));
    assert(s.position == 2);
    assert(s.line == 1);

    s = textRange("#test\n");
    assert(comment(s));
    assert(s.position == 6);
    assert(s.line == 1);

    s = textRange("#test\ntest");
    assert(comment(s));
    assert(s.position == 6);
    assert(s.line == 1);
    assert(s.front == 't');
}

/// 空白
alias more0!(sel!(comment, whiteSpaces)) sp;

/// 識別子の先頭文字
alias sel!(rng!('a', 'z'), rng!('A', 'Z'), ch!'_') idHead;

/// 識別子の尾部の文字
alias sel!(idHead, rng!('0', '9')) idTail;

/// 識別子
alias seq!(idHead, more0!idTail) identifier;

///
unittest {
    auto identifiers = ["test", "test1234", "_test1234", "__test__1234__"];
    foreach(s; identifiers) {
        auto src = s;
        assert(identifier(src), s);
        assert(src.empty, s);
    }

    auto notIdentifiers = ["", "0", "0test", "0test__", ";test", " test", "\rtest"];
    foreach(s; notIdentifiers) {
        auto src = s;
        assert(!identifier(src), s);
        assert(src == s, s);
    }
}

/// 文字範囲
alias seq!(ch!'[', sp, charLiteral, sp, str!"..", sp, charLiteral, sp, ch!']') rangeParser;

///
unittest {
    auto s = textRange(`['a'..'z']`);
    assert(rangeParser(s));
    assert(s.line == 0);
    assert(s.empty);

    s = textRange(`[ 'a'  ..    'z'  ]`);
    assert(rangeParser(s));
    assert(s.line == 0);
    assert(s.empty);

    s = textRange(`[ 'a'
            ..
            'z'  
            ]`);
    assert(rangeParser(s));
    assert(s.line == 3);
    assert(s.empty);

    s = textRange(`['a'..'z'`);
    assert(!rangeParser(s));
    assert(s.position == 0);
    assert(s.front == '[');

    s = textRange(`['a'.'z']`);
    assert(!rangeParser(s));
    assert(s.position == 0);
    assert(s.front == '[');
}

/// 文字集合
alias seq!(ch!'[', sp, stringLiteral, sp, ch!']') setParser;

///
unittest {
    auto s = textRange(`["0123456789"]`);
    assert(setParser(s));
    assert(s.line == 0);
    assert(s.empty);

    s = textRange(`[ "test"  ]`);
    assert(setParser(s));
    assert(s.line == 0);
    assert(s.empty);

    s = textRange(`[
            "test"
            ]`);
    assert(setParser(s));
    assert(s.line == 2);
    assert(s.empty);

    s = textRange(`["test"`);
    assert(!setParser(s));
    assert(s.position == 0);
    assert(s.front == '[');

    s = textRange(`["test]`);
    assert(!setParser(s));
    assert(s.position == 0);
    assert(s.front == '[');
}

/// 任意文字
alias ch!'.' anyParser;

/// PEG識別子
alias node!(PegNode.ID, identifier) pegIdentifier;

/// PEG因子色
alias sel!(
    pegIdentifier,
    node!(PegNode.ANY, anyParser),
    node!(PegNode.CHAR, charLiteral),
    node!(PegNode.STRING, stringLiteral),
    node!(PegNode.RANGE, rangeParser),
    node!(PegNode.SET, setParser),
    seq!(ch!'(', sp, pegSelect, sp, ch!')')) pegFactor;

/// 有るか無いか演算子
alias node!(PegNode.OPTION, seq!(pegFactor, sp, ch!'?')) pegOption;

/// 0個以上演算子
alias node!(PegNode.MORE0, seq!(pegFactor, sp, ch!'*')) pegMore0;

/// 1個以上演算子
alias node!(PegNode.MORE1, seq!(pegFactor, sp, ch!'+')) pegMore1;

/// PEG後置演算子色
alias sel!(pegOption, pegMore0, pegMore1, pegFactor) pegPostfix;

/// 有るかテスト演算子
alias node!(PegNode.AND, seq!(ch!'&', sp, pegPostfix)) pegTest;

/// 無いかテスト演算子
alias node!(PegNode.NOT, seq!(ch!'!', sp, pegPostfix)) pegNotTest;

/// 前置演算子式
alias sel!(pegTest, pegNotTest, pegPostfix) pegPrefix;

/// 連接式
alias node!(PegNode.SEQUENCE, seq!(pegPrefix, more0!(seq!(sp, pegPrefix)))) pegSequence;

/// 選択式(再帰的定義のために関数にする)
bool pegSelect(R)(ref R src) {
    return node!(PegNode.SELECT, seq!(pegSequence, more0!(seq!(sp, ch!'/', sp, pegSequence))))(src);
}

/// 定義式
alias node!(PegNode.DEFINE, seq!(pegIdentifier, sp, ch!'=', sp, pegSelect, sp, ch!';')) pegDefine;

/// PEGソース
alias node!(PegNode.ROOT, seq!(more0!(seq!(sp, pegDefine)), sp, end)) pegSource;

version(unittest) {
    /// ノードのテストを行う
    void assertNode(const(AST!PegNode.Node) node, PegNode[] children...) {
        assert(node.length == children.length);
        foreach(i, c; children) {
            assert(node[i].type == children[i]);
        }
    }
}

// 定義式
unittest {
    auto src = `a = 'a';`;
    auto s = astRange!PegNode(src);
    assert(pegSource(s));
    assert(s.empty);
    assert(s.ast.root !is null);
    assert(s.ast.root.type == PegNode.ROOT);

    const root = s.ast.root;
    assertNode(root, PegNode.DEFINE);

    const def = root[0];
    assertNode(def, PegNode.ID, PegNode.SELECT);
    assert(src[def.begin .. def.end] == `a = 'a';`);

    const id = def[0];
    assert(src[id.begin .. id.end] == `a`);

    const sel = def[1];
    assertNode(sel, PegNode.SEQUENCE);
    assert(src[sel.begin .. sel.end] == `'a'`);

    const seq = sel[0];
    assertNode(seq, PegNode.CHAR);
    assert(src[seq.begin .. seq.end] == `'a'`);

    auto c = seq[0];
    assert(src[c.begin .. c.end] == `'a'`);
}

