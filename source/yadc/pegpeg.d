module yadc.pegpeg;

import std.array : array, empty;
import std.traits : isNarrowString;

import yadc.peg;

import compile_time_unittest : enableCompileTimeUnittest;
mixin enableCompileTimeUnittest;

/// PEGノードの型
enum PegNode {
    STRING,   /// リテラル文字列
    CHAR,     /// リテラル文字
    ID,       /// 識別子
    NODE_ID,  /// ノード識別子
    NEW_LINE, /// 改行ノード
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

/// PEGソースRangeの生成
auto pegSourceRange(R)(R r) if(!isNarrowString!R) {return astRange!(PegNode, R)(r);}

/// ditto
auto pegSourceRange(R)(R r) if(isNarrowString!R) {return pegSourceRange(array(r));}

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
alias seq!(ch!'#', more0!(seq!(not!newLineChars, any)), sel!(newLine, end)) comment;

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
alias node!(PegNode.ID, seq!(idHead, more0!idTail)) pegIdentifier;

///
unittest {
    auto identifiers = ["t", "_", "test", "test1234", "_test1234", "__test__1234__"];
    foreach(s; identifiers) {
        auto src = pegSourceRange(s);
        assert(pegIdentifier(src), s);
        assert(src.empty, s);
    }

    auto notIdentifiers = ["", "0", "0test", "0test__", ";test", " test", "\rtest"];
    foreach(s; notIdentifiers) {
        auto src = pegSourceRange(s);
        assert(!pegIdentifier(src), s);
        assert(src.position == 0);
    }
}

/// 文字リテラルパーサー
alias node!(PegNode.CHAR, charLiteral) pegCharLiteral;

/// 文字列リテラルパーサー
alias node!(PegNode.STRING, stringLiteral) pegStringLiteral;

/// 文字範囲
alias node!(PegNode.RANGE, seq!(ch!'[', sp, pegCharLiteral, sp, str!"..", sp, pegCharLiteral, sp, ch!']')) pegCharRange;

///
unittest {
    auto s = pegSourceRange(`['a'..'z']`);
    assert(pegCharRange(s));
    assert(s.line == 0);
    assert(s.empty);

    s = pegSourceRange(`[ 'a'  ..    'z'  ]`);
    assert(pegCharRange(s));
    assert(s.line == 0);
    assert(s.empty);

    s = pegSourceRange(`[ 'a'
            ..
            'z'  
            ]`);
    assert(pegCharRange(s));
    assert(s.line == 3);
    assert(s.empty);

    s = pegSourceRange(`['a'..'z'`);
    assert(!pegCharRange(s));
    assert(s.position == 0);
    assert(s.front == '[');

    s = pegSourceRange(`['a'.'z']`);
    assert(!pegCharRange(s));
    assert(s.position == 0);
    assert(s.front == '[');
}

/// 文字集合
alias node!(PegNode.SET, seq!(ch!'[', sp, pegStringLiteral, sp, ch!']')) pegCharSet;

///
unittest {
    auto s = pegSourceRange(`["0123456789"]`);
    assert(pegCharSet(s));
    assert(s.line == 0);
    assert(s.empty);

    s = pegSourceRange(`[ "test"  ]`);
    assert(pegCharSet(s));
    assert(s.line == 0);
    assert(s.empty);

    s = pegSourceRange(`[
            "test"
            ]`);
    assert(pegCharSet(s));
    assert(s.line == 2);
    assert(s.empty);

    s = pegSourceRange(`["test"`);
    assert(!pegCharSet(s));
    assert(s.position == 0);
    assert(s.front == '[');

    s = pegSourceRange(`["test]`);
    assert(!pegCharSet(s));
    assert(s.position == 0);
    assert(s.front == '[');
}

/// 任意文字
alias node!(PegNode.ANY, ch!'.') pegAny;

/// 終端
alias node!(PegNode.END, ch!'$') pegEnd;

/// PEG原始式
alias sel!(
    pegIdentifier,
    pegStringLiteral,
    pegCharLiteral,
    pegAny,
    pegEnd,
    pegCharRange,
    pegCharSet,
    seq!(ch!'(', sp, pegSelect, sp, ch!')')) pegAtom;

/// 有るか無いか演算子
alias node!(PegNode.OPTION, seq!(pegAtom, sp, ch!'?')) pegOption;

/// 0個以上演算子
alias node!(PegNode.MORE0, seq!(pegAtom, sp, ch!'*')) pegMore0;

/// 1個以上演算子
alias node!(PegNode.MORE1, seq!(pegAtom, sp, ch!'+')) pegMore1;

/// PEG後置演算子色
alias sel!(pegOption, pegMore0, pegMore1, pegAtom) pegPostfix;

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

/// ノード識別子式
alias node!(PegNode.NODE_ID, seq!(ch!'{', sp, pegIdentifier, sp, ch!'}')) pegNodeIdentifier;

/// 改行ノード識別子式
alias node!(PegNode.NEW_LINE, seq!(ch!':', sp, pegIdentifier, sp, ch!':')) pegNewLine;

/// 定義式
alias node!(PegNode.DEFINE, seq!(sel!(pegNodeIdentifier, pegNewLine, pegIdentifier), sp, ch!'=', sp, pegSelect, sp, ch!';')) pegDefine;

/// PEGソース
alias node!(PegNode.ROOT, seq!(more0!(seq!(sp, pegDefine)), sp, end)) pegSource;

version(unittest) {
    /**
     *  ノードのテストを行う
     *
     *  Params:
     *      node = ノード
     *      children = 期待される子ノード。子ノードが無い場合は何も指定しない。
     */
    void assertNode(const(AST!PegNode.Node) node, PegNode[] children...) {
        assert(node.length == children.length);
        foreach(i, c; children) {
            assert(node[i].type == children[i]);
        }
    }
}

// 定義式
unittest {
    auto src = `{a} = 'a';`;
    auto s = pegSourceRange(src);
    assert(pegSource(s));
    assert(s.empty);
    assert(s.ast.roots.length == 1);
    assert(s.ast.roots[0].type == PegNode.ROOT);

    const root = s.ast.roots[0];
    assertNode(root, PegNode.DEFINE);

    const def = root[0];
    assertNode(def, PegNode.NODE_ID, PegNode.SELECT);
    assert(src[def.begin .. def.end] == `{a} = 'a';`);

    const nodeId = def[0];
    assertNode(nodeId, PegNode.ID);

    const id = nodeId[0];
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

/**
 *  PEGの構文木からD言語ソースをコンパイルする
 *
 *  Params:
 *      T = ノードタグ型
 *      src = ソース文字列
 *      node = ノード
 *  Returns:
 *      PEGのD言語ソース
 */
string compilePeg(T)(string src, const(AST!PegNode.Node) node) {
    alias typeof(node) Node;

    // ノード範囲の文字列を切り出す
    string source(Node n) {return src[n.begin .. n.end];}

    // ノードをコンパイルする
    string compile(Node child) {return compilePeg!T(src, child);}

    // 子ノードをコンパイルし、カンマで連結する
    string compileChildren(Node parent, string sep) {
        auto result = "";
        foreach(n; parent.children) {
            if(!result.empty) {
                result ~= sep;
            }
            result ~= compile(n);
        }
        return result;
    }

    final switch(node.type) {
    case PegNode.STRING:
        return "str!(" ~ source(node) ~ ")";
    case PegNode.CHAR:
        return "ch!(" ~ source(node) ~ ")";
    case PegNode.ID:
        return source(node);
    case PegNode.ANY:
        return "any";
    case PegNode.RANGE:
        assert(node.length == 2);
        assert(node[0].type == PegNode.CHAR);
        assert(node[1].type == PegNode.CHAR);
        return "rng!(" ~ source(node[0]) ~ "," ~ source(node[1]) ~ ")";
    case PegNode.SET:
        assert(node.length == 1);
        assert(node[0].type == PegNode.STRING);
        return "set!(" ~ source(node[0]) ~ ")";
    case PegNode.END:
        return "end";
    case PegNode.OPTION:
        assert(node.length == 1);
        return "opt!(" ~ compile(node[0]) ~ ")";
    case PegNode.AND:
        assert(node.length == 1);
        return "and!(" ~ compile(node[0]) ~ ")";
    case PegNode.NOT:
        assert(node.length == 1);
        return "not!(" ~ compile(node[0]) ~ ")";
    case PegNode.MORE0:
        assert(node.length == 1);
        return "more0!(" ~ compile(node[0]) ~ ")";
    case PegNode.MORE1:
        assert(node.length == 1);
        return "more1!(" ~ compile(node[0]) ~ ")";
    case PegNode.SELECT:
        if(node.length == 1) {
            return compile(node[0]);
        } else {
            return "sel!(" ~ compileChildren(node, ",") ~ ")";
        }
    case PegNode.SEQUENCE:
        if(node.length == 1) {
            return compile(node[0]);
        } else {
            return "seq!(" ~ compileChildren(node, ",") ~ ")";
        }
    case PegNode.DEFINE:
        {
            assert(node.length == 2);
            assert(node[1].type == PegNode.SELECT);
            auto exp = compile(node[1]);
            if(node[0].type == PegNode.ID) {
                auto id = source(node[0]);
                return "bool " ~ id ~ "(R)(ref R s){return " ~ exp ~ "(s);}";
            } else if(node[0].type == PegNode.NODE_ID) {
                assert(node[0].length == 1);
                auto id = source(node[0][0]);
                return "bool " ~ id ~ "(R)(ref R s){return node!(" ~ T.stringof ~ "." ~ id ~ "," ~ exp ~ ")(s);}";
            } else if(node[0].type == PegNode.NEW_LINE) {
                assert(node[0].length == 1);
                auto id = source(node[0][0]);
                return "bool " ~ id ~ "(R)(ref R s){return addLine!(" ~ exp ~ ")(s);}";
            } else {
                assert(false, "unexpected node type");
            }
        }
    case PegNode.ROOT:
        return compileChildren(node, "\n");
    case PegNode.NODE_ID:
        assert(false, "unexpected NODE_ID");
    case PegNode.NEW_LINE:
        assert(false, "unexpected NEW_LINE");
    }
}

/**
 *  PEGソースをD言語にコンパイルする
 *
 *  Params:
 *      T = ノードタグ型
 *      src = PEGソース
 *  Returns:
 *      D言語ソース
 */
string compilePeg(T)(string src) {
    auto s = pegSourceRange(src);
    if(!pegSource(s) || s.ast.roots.length < 1) {
        throw new Exception("PEG compile error!");
    }
    return compilePeg!T(src, s.ast.roots[0]);
}

///
unittest {
    mixin(compilePeg!int(`a = "test";`));

    auto src = "test";
    assert(a(src));

    src = "tes";
    assert(!a(src));
}

