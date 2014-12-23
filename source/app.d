module app;

import std.stdio : writefln;

import yadc.peg;
import yadc.pegpeg;

import compile_time_unittest : enableCompileTimeUnittest;
mixin enableCompileTimeUnittest;

/// PEGの文法
enum PEG_GRAMMAR = q{
# PEG文法の定義

# 改行
:newLine: = '\r' '\n'? / '\n';

# 空白
space = [" \t\v\f"];

# 空白列
whiteSpaces = (newLine / space)+;

# コメント
comment = '#' (!newLine .)* (newLine / $);

# 空白
sp = (comment / whiteSpaces)*;

# 8進数
octDigit = ['0'..'7'];

# 16進数
hexDigit = ['0'..'9'] / ['a'..'f'] / ['A'..'F'];

# エスケープシーケンス文字
escChars = ["\'\"\?\\abfnrtv0"];

# 16進エスケープシーケンス文字
hexEscape = 'x' hexDigit hexDigit;

# 8進エスケープシーケンス文字
octEscape = octDigit octDigit? octDigit?;

# 16進数4文字
hex4Digit = hexDigit hexDigit hexDigit hexDigit;

# ユニコード16ビットエスケープシーケンス
unicode16Escape = 'u' hex4Digit;

# ユニコード32ビットエスケープシーケンス
unicode32Escape = 'U' hex4Digit hexDigit;

# エスケープシーケンス
escapeSequence = '\\' (
        escChars
        / hexEscape
        / octEscape
        / unicode16Escape
        / unicode32Escape);

# 文字リテラル
{CHAR} = '\'' (escapeSequence / !'\'' .) '\'';

# 文字列リテラル
{STRING} = '\"' (escapeSequence / !'\"' .)* '\"';

# 識別子の先頭文字
idHead = ['a'..'z'] / ['A'..'Z'] / '_';

# 識別子の尾部文字
idTail= idHead / ['0'..'9'];

# 識別子
{ID} = idHead idTail*;

# 文字範囲
{RANGE} = '[' sp CHAR sp ".." sp CHAR sp ']';

# 文字セット
{SET} = '[' sp STRING sp ']';

# 任意文字
{ANY} = '.';

# ソース終端
{END} = '$';

# 原始式
atom = ID / STRING / CHAR / ANY / END / RANGE / SET / '(' sp SELECT sp ')';

# 有るか無いか演算子
{OPTION} = atom sp '?';

# 0個以上演算子
{MORE0} = atom sp '*';

# 1個以上演算子
{MORE1} = atom sp '+';

# 後置演算子式
postfix = OPTION / MORE0 / MORE1 / atom;

# 有るかテスト演算子式
{AND} = '&' sp postfix;

# 無いかテスト演算子式
{NOT} = '!' sp postfix;

# 前置演算子式
prefix = AND / NOT / postfix;

# 連接式
{SEQUENCE} = prefix (sp prefix)*;

# 選択式
{SELECT} = SEQUENCE (sp '/' sp SEQUENCE)*;

# ノード識別子
{NODE_ID} = '{' sp ID sp '}';

# 改行ノード識別子
{NEW_LINE} = ':' sp ID sp ':';

# 定義式
{DEFINE} = (NODE_ID / NEW_LINE / ID) sp '=' sp SELECT sp ';';

# PEGソース
{ROOT} = (sp DEFINE)* sp $;
};

// PEG文法に従ってPEG構文解析器を生成してmixin
mixin(compilePeg!PegNode(PEG_GRAMMAR));

/// メイン関数
void main() {
    // PEG文法自身を自分自身で解析する
    auto s = pegSourceRange(PEG_GRAMMAR);
    auto result = ROOT(s);
    assert(result);

    // 解析結果を表示
    writefln("%s", s.ast.roots[0]);
}

