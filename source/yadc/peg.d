module yadc.peg;

import compile_time_unittest : enableCompileTimeUnittest;

mixin enableCompileTimeUnittest;

import std.range :
    isInputRange,
    isForwardRange,
    empty,
    front,
    save,
    popFront;

/**
 *  任意の1文字認識する
 *
 *  Params:
 *      R = ソースの型
 *      src = ソース
 *  Returns:
 *      何か1文字あればtrue
 */
bool any(R)(ref R src) if(isInputRange!R) {
    if(src.empty) {
        return false;
    } else {
        src.popFront();
        return true;
    }
}

///
unittest {
    auto src = "test";

    // 次の1文字があればtrue
    assert(any(src));
    assert(src.front == 'e');

    // ソースが空であれば解析失敗
    src = "";
    assert(!any(src));
    assert(src == "");
}

/**
 *  指定した1文字を認識する
 *
 *  Params:
 *      C = 認識する文字
 *      R = ソースの型
 *      src = ソース
 *  Returns:
 *      現在位置がCであればtrue
 */
template ch(alias C) {
    /// ditto
    bool ch(R)(ref R src) if(isInputRange!R) {
        if(!src.empty && src.front == C) {
            src.popFront();
            return true;
        } else {
            return false;
        }
    }
}

///
unittest {
    auto src = "test";

    // 次の1文字が指定文字であればtrue
    assert(ch!'t'(src));
    assert(src.front == 'e');

    // 指定文字でなければfalseで元の位置のまま
    assert(!ch!'t'(src));
    assert(src.front == 'e');

    // 空文字列でもfalse
    src = "";
    assert(!ch!'t'(src));
    assert(src == "");
}

/**
 *  ソースの終端を認識する
 *
 *  Params:
 *      R = ソースの型
 *      src = ソース
 *  Returns:
 *      ソースが空になっていればtrue
 */
bool end(R)(ref R src) if(isInputRange!R) {
    return src.empty;
}

///
unittest {
    auto s = "test";

    // 1文字でも残っていればfalse
    assert(!end(s));
    assert(s.front == 't');

    s = "a";
    assert(!end(s));
    assert(s.front == 'a');

    // 空文字列であればtrue
    s = "";
    assert(end(s));
}

/**
 *  指定した文字列を認識する
 *
 *  Params:
 *      S = 認識する文字列
 *      R = ソースの型
 *      src = ソース
 *  Returns:
 *      ソースの現在位置から先が指定した文字列であればtrue
 */
template str(alias S) if(isInputRange!(typeof(S))) {
    /// ditto
    bool str(R)(ref R src) if(isForwardRange!R) {
        auto before = src.save;
        scope(failure) src = before;

        foreach(c; S) {
            if(src.empty || src.front != c) {
                src = before;
                return false;
            }
            src.popFront();
        }
        return true;
    }
}

///
unittest {
    auto src = "test";

    // ソースが指定文字列で開始されていればtrue
    assert(str!"te"(src));
    assert(src.front == 's');

    // 指定文字列でなければfalseで元の位置のまま
    assert(!str!"te"(src));
    assert(src.front == 's');

    // 文字列全体が一致していなければfalse
    assert(src == "st");
    assert(!str!"ss"(src));
    assert(src.front == 's');

    // 空文字列でもfalse
    src = "";
    assert(!str!"te"(src));
    assert(src == "");
}

/**
 *  文字集合のいずれか1文字を解析する
 *
 *  Params:
 *      S = 文字集合
 *      R = ソースの型
 *      src = ソース
 *  Returns:
 *      ソースの先頭が文字集合のいずれか1文字であればtrue
 */
template set(alias S) if(isInputRange!(typeof(S))) {
    /// ditto
    bool set(R)(ref R src) if(isInputRange!R) {
        if(!src.empty) {
            foreach(c; S) {
                if(c == src.front) {
                    src.popFront();
                    return true;
                }
            }
        }
        return false;
    }
}

///
unittest {
    auto s = "test";

    // 先頭1文字が指定文字であればtrue
    assert(set!"stuv"(s));
    assert(s.front == 'e');

    // 先頭1文字が違う文字であればfalse
    assert(!set!"stuv"(s));

    // 空文字列でもfalse
    s = "";
    assert(!set!"stuv"(s));
}

/**
 *  ソースの先頭が[C1, C2]に含まれれば解析成功
 *
 *  Params:
 *      C1 = 文字範囲の始点
 *      C2 = 文字範囲の終点
 *      R = ソースの型
 *      src = ソース
 *  Returns:
 *      ソースの先頭が[C1, C2]に含まれればtrue
 */
template rng(alias C1, alias C2) {
    /// ditto
    bool rng(R)(ref R src) if(isInputRange!R) {
        if(!src.empty && C1 <= src.front && src.front <= C2) {
            src.popFront();
            return true;
        }
        return false;
    }
}

///
unittest {
    auto s = "test";

    // 先頭1文字が指定文字であればtrue
    assert(rng!('a', 'z')(s));
    assert(s.front == 'e');

    // 先頭1文字が違う文字であればfalse
    assert(!rng!('f', 'z')(s));

    // 空文字列でもfalse
    s = "";
    assert(!rng!('a', 'z')(s));
}

/**
 *  Pが解析成功した場合成功する
 *  ソースの位置は必ず元に戻る
 *
 *  Params:
 *      P = 解析を試みるパーサ
 *      R = ソースの型
 *      src = ソース
 *  Returns:
 *      Pの解析結果
 */
template and(alias P) {
    /// ditto
    bool and(R)(ref R src) if(isForwardRange!R) {
        auto before = src.save;
        scope(exit) src = before;

        return P(src);
    }
}

///
unittest {
    auto s = "test";

    // chの解析を試みる。成功したらtrueだが、読み込み位置は元のままとなる。
    assert(and!(ch!'t')(s));
    assert(s.front == 't');

    // 解析失敗
    assert(!and!(ch!'a')(s));
    assert(s.front == 't');
}

/**
 *  Pが解析成功した場合失敗し、失敗した場合成功する
 *  ソースの位置は必ず元に戻る
 *
 *  Params:
 *      P = 解析を試みるパーサ
 *      R = ソースの型
 *      src = ソース
 *  Returns:
 *      Pの解析結果のnot
 */
template not(alias P) {
    /// ditto
    bool not(R)(ref R src) if(isForwardRange!R) {
        auto before = src.save;
        scope(exit) src = before;

        return !P(src);
    }
}

///
unittest {
    auto s = "test";

    // chの解析を試みる。成功したらfalse
    assert(!not!(ch!'t')(s));
    assert(s.front == 't');

    // 解析失敗時はtrue
    assert(not!(ch!'a')(s));
    assert(s.front == 't');
}

/**
 *  Pの解析を試みる
 *  Pが失敗しても成功とする
 *  Pが成功した場合、読み込み位置は進められる
 *
 *  Params:
 *      P = 解析を試みるパーサー
 *      R = ソースの型
 *      src = ソース
 *  Returns:
 *      解析成功・失敗に関わらずtrue
 */
template opt(alias P) {
    /// ditto
    bool opt(R)(ref R src) {
        P(src);
        return true;
    }
}

///
unittest {
    auto s = "test";

    // chの解析を試みる。成功時はtrueとなり、読み込み位置が進められる
    assert(opt!(ch!'t')(s));
    assert(s.front == 'e');

    // 解析失敗時もtrue
    assert(opt!(ch!'a')(s));
    assert(s.front == 'e');
}

/**
 *  Pの解析を試みる
 *  Pが失敗しても成功とする
 *  Pが成功する限り解析は繰り返され、読み込み位置もその分進められる
 *
 *  Params:
 *      P = 解析を試みるパーサー
 *      R = ソースの型
 *      src = ソース
 *  Returns:
 *      解析成功・失敗に関わらずtrue
 */
template more0(alias P) {
    /// ditto
    bool more0(R)(ref R src) {
        while(P(src)) {}
        return true;
    }
}

///
unittest {
    auto s = "test";

    // chの解析を試みる。成功時はtrueとなり、読み込み位置が進められる
    assert(more0!(ch!'t')(s));
    assert(s.front == 'e');

    // 解析失敗時もtrue
    assert(more0!(ch!'a')(s));
    assert(s.front == 'e');

    // 解析できる限り繰り返し
    assert(more0!(rng!('a', 'z'))(s));
    assert(s.empty);
}

/**
 *  Pの解析を試みる
 *  Pが一度も成功しなければ失敗とする
 *  Pが成功する限り解析は繰り返され、読み込み位置もその分進められる
 *
 *  Params:
 *      P = 解析を試みるパーサー
 *      R = ソースの型
 *      src = ソース
 *  Returns:
 *      最低1回解析成功すればtrue
 */
template more1(alias P) {
    /// ditto
    bool more1(R)(ref R src) {
        bool result = false;
        while(P(src)) {
            result = true;
        }
        return result;
    }
}

///
unittest {
    auto s = "test";

    // chの解析を試みる。成功時はtrueとなり、読み込み位置が進められる
    assert(more1!(ch!'t')(s));
    assert(s.front == 'e');

    // 解析失敗時はfalsetrue
    assert(!more1!(ch!'a')(s));
    assert(s.front == 'e');

    // 解析できる限り繰り返し
    assert(more1!(rng!('a', 'z'))(s));
    assert(s.empty);
}

/**
 *  パーサーの連接を解析する
 *  指定したパーサーを順に呼び出し、いずれか1つで失敗したら失敗とする。
 *
 *  Params:
 *      P = 呼び出すパーサー列
 *      R = ソースの型
 *      src = ソース
 *  Returns:
 *      全て解析成功したらtrue
 */
template seq(P...) {
    /// ditto
    bool seq(R)(ref R src) {
        auto before = src.save;
        scope(failure) src = before;

        foreach(p; P) {
            if(!p(src)) {
                src = before;
                return false;
            }
        }
        return true;
    }
}

unittest {
    auto s = "test";

    // 先頭2文字を解析
    assert(seq!(ch!'t', ch!'e')(s));
    assert(s.front == 's');

    // 1文字目で異なる場合、元に戻る
    assert(!seq!(ch!'e', ch!'e')(s));
    assert(s.front == 's');

    // 2文字目で異なる場合も、全体が元に戻る
    assert(!seq!(ch!'s', ch!'e')(s));
    assert(s.front == 's');
}

/**
 *  いずれか1つのパーサー解析する
 *  指定したパーサーを順に呼び出し、いずれか1つで成功したら成功とする
 *  全てのパーサーで失敗した場合、失敗と成る
 *
 *  Params:
 *      P = 呼び出すパーサー列
 *      R = ソースの型
 *      src = ソース
 *  Returns:
 *      全て解析成功したらtrue
 */
template sel(P...) {
    /// ditto
    bool sel(R)(ref R src) {
        foreach(p; P) {
            if(p(src)) {
                return true;
            }
        }
        return false;
    }
}

///
unittest {
    auto s = "test";

    // いずれかのパーサーでマッチすれば成功
    assert(sel!(ch!'t', ch!'e')(s));
    assert(s.front == 'e');
    assert(sel!(ch!'t', ch!'e')(s));
    assert(s.front == 's');

    // 全てのパーサーで異なる場合、元に戻る
    assert(!sel!(ch!'t', ch!'e')(s));
    assert(s.front == 's');
}

unittest {
    // 1以上の数字
    alias rng!('1', '9') n1;

    // 0以上の数字
    alias rng!('0', '9') n0;

    // カンマ区切り数字の先頭。最初の1桁は[1, 9]で、カンマの出てこない最初の3桁まで
    alias seq!(n1, opt!n0, opt!n0) digitsHead;

    // 数字のカンマで区切られている末尾部分。
    alias seq!(ch!',', n0, n0, n0) digitsTail;

    // ゼロの場合
    alias seq!(ch!'0', end) zero;

    // 数字。ゼロまたは数字列
    alias sel!(zero, seq!(digitsHead, more0!digitsTail, end)) digits;

    // 以下は成功するソース
    foreach(s; [
            "0",
            "1",
            "12",
            "123",
            "1,234",
            "12,234",
            "123,234",
            "1,000",
            "10,000",
            "100,000",
            "1,000,000",
            ]) {
        auto src = s;
        assert(digits(src) && src.empty, s);
    }

    // 以下は失敗するソース
    foreach(s; [
            "01",
            "012",
            ",",
            ",1"
            ",12",
            ",123",
            "1,",
            "12,",
            "123,",
            "1234,",
            "1234,234",
            "1,",
            "1,2",
            "1,23",
            "1,2345",
            "0,234",
            ]) {
        auto src = s;
        assert(!digits(src) && src == s, s);
    }
}

unittest {
    // 改行文字を認識
    alias sel!(seq!(ch!'\r', opt!(ch!'\n')), ch!'\n') newLine;

    // 改行1つの解析
    foreach(nl; ["\r", "\n", "\r\n"] ) {
        assert(newLine(nl) && nl.empty);
    }

    // これは2つの改行になる
    auto s = "\n\r";
    assert(newLine(s) && s.front == '\r');
    assert(newLine(s) && s.empty);
}

/**
 *  行番号をカウントするRange
 */
struct LineRange(R) if(isInputRange!R) {

    /**
     *  内部Rangeを指定して生成する
     *
     *  Params:
     *      r = 内部Range
     */
    this(R r) {
        inner = r;
    }

    /**
     *  行番号を返す
     *
     *  Returns:
     *      現在の行番号
     */
    @property size_t line() @safe @nogc nothrow pure {
        return line_;
    }

    /**
     *  行番号をカウントする
     */
    void addLine() @safe @nogc nothrow {
        ++line_;
    }

    static if(isForwardRange!R) {
        /**
         *  現在位置を記録する
         *
         *  Returns:
         *      現在位置のRange
         */
        @property LineRange save() {
            LineRange result;
            result.inner = inner.save;
            result.line_ = line;
            return result;
        }
    }

    /// その他の呼び出しは内部Rangeに任せる
    alias inner this;

    /// 内部Range
    R inner;

private:

    /// 行番号
    size_t line_;
}

/**
 *  指定Rangeを行番号付きRangeに変換して返す
 *
 *  Params:
 *      R = 行番号付きRangeに変換するRange
 *  Returns:
 *      行番号付きRange
 */
LineRange!R lineRange(R)(R r) {
    return LineRange!R(r);
}

/**
 *  指定パーサーが解析成功したら行番号をカウントアップする
 *
 *  Params:
 *      P = 改行パーサー
 *      R = ソースの型
 *      src = ソース
 *  Returns:
 *      Pの解析結果
 */
template addLine(alias P) {
    /// ditto
    bool addLine(R)(ref LineRange!R src) {
        if(P(src)) {
            src.addLine();
            return true;
        } else {
            return false;
        }
    }
}

///
unittest {
    auto s = "\r\n";
    auto ls = lineRange(s);

    // 最初は行番号0
    assert(ls.line == 0);

    auto ls2 = ls.save;

    // 行番号をカウントアップ
    assert(addLine!(ch!'\r')(ls));
    assert(ls.front == '\n');
    assert(ls.line == 1);

    // saveした方は変わらない
    assert(ls2.front == '\r');
    assert(ls2.line == 0);

    // 元に戻せること
    ls = ls2;
    assert(ls.front == '\r');
    assert(ls.line == 0);
}

/**
 *  文字単位の位置を持つRange
 */
struct PositionRange(R) if(isInputRange!R) {

    /**
     *  内部Rangeを指定して生成する
     *
     *  Params:
     *      r = 内部Range
     */
    this(R r) {
        inner = r;
    }

    /**
     *  文字単位の位置を返す
     *
     *  Returns:
     *      文字単位の位置
     */
    @property size_t position() const @safe @nogc nothrow pure {
        return position_;
    }

    /**
     *  先頭要素を破棄する
     */
    void popFront() {
        inner.popFront();

        // 進んだ分をカウント
        ++position_;
    }

    static if(isForwardRange!R) {
        /**
         *  現在位置を記録する
         *
         *  Returns:
         *      現在位置のRange
         */
        @property PositionRange save() {
            PositionRange result;
            result.inner = inner.save;
            result.position_ = position;
            return result;
        }
    }

    /// その他の呼び出しは内部Rangeに任せる
    alias inner this;

    /// 内部Range
    R inner;

private:

    /// 文字単位の位置
    size_t position_;
}

/**
 *  指定Rangeを位置付きRangeに変換して返す
 *
 *  Params:
 *      R = 位置号付きRangeに変換するRange
 *  Returns:
 *      位置付きRange
 */
PositionRange!R positionRange(R)(R r) {
    return PositionRange!R(r);
}

///
unittest {
    auto s = "test";
    auto ps = positionRange(s);

    // 最初は位置0
    assert(ps.position == 0);

    auto ps2 = ps.save;

    // 1文字進めた場合
    assert(ch!'t'(ps));
    assert(ps.position == 1);
    assert(ps.front == 'e');

    // saveしたものは変わらない
    assert(ps2.position == 0);
    assert(ps2.front == 't');

    // 2文字目
    assert(ch!'e'(ps));
    assert(ps.position == 2);
    assert(ps.front == 's');

    // 元に戻せること
    ps = ps2;
    assert(ps.position == 0);
    assert(ps.front == 't');

    // 途中で失敗しても位置は0のまま
    assert(!str!"tess"(ps));
    assert(ps.position == 0);
    assert(ps.front == 't');
    assert(str!"test"(ps)); // こちらは成功
    assert(ps.empty && ps.position == 4);
}

/// テキスト解析用の位置・行番号を保持したRange
alias TextRange(R) = LineRange!(PositionRange!R);

/// 指定RangeをTextRangeに変換
auto textRange(R)(R src) {
    return TextRange!R(positionRange(src));
}

///
unittest {
    auto s = "test\n2test";
    auto ts = textRange(s);

    // 最初は位置0
    assert(ts.position == 0);
    assert(ts.line == 0);

    auto ts2 = ts.save;

    // testを読み込み
    assert(str!"test"(ts));
    assert(ts.position == 4);
    assert(ts.line == 0);
    assert(ts.front == '\n');

    // saveしたものは変わらない
    assert(ts2.position == 0);
    assert(ts2.line == 0);
    assert(ts2.front == 't');

    // 改行を読み込み
    assert(addLine!(ch!'\n')(ts));
    assert(ts.position == 5);
    assert(ts.line == 1);
    assert(ts.front == '2');

    // 元に戻せること
    ts = ts2;
    assert(ts.position == 0);
    assert(ts.line == 0);
    assert(ts.front == 't');
}

/**
 *  Params:
 *      B = 解析開始時の処理
 *      S = 解析成功時の処理
 *      F = 解析失敗時の処理。Pでの例外発生時にも呼び出される。
 *      P = 呼び出すパーサー
 *      R = ソースの型
 *      src = ソース
 *  Returns:
 *      Pの解析結果
 */
template action(alias B, alias S, alias F, alias P) {
    /// ditto
    bool action(R)(ref R src) {
        // 解析開始
        B(src);

        // Pの呼び出し。例外発生時はFを呼んで整合性を保つ
        bool result;
        {
            scope(failure) F(src);
            result = P(src);
        }

        // 結果を見て解析成功・失敗のどちらかを呼ぶ
        if(result) {
            S(src);
            return true;
        } else {
            F(src);
            return false;
        }
    }
}

///
unittest {
    // アクションで変更する変数
    bool begin = false;
    bool success = false;
    bool fail = false;

    // リセット用
    void reset() {
        begin = false;
        success = false;
        fail = false;
    }

    // 解析開始・成功・失敗でそれぞれ変数を設定するアクション
    alias action!(
        (s) {begin = true;},
        (s) {success = true;},
        (s) {fail= true;},
        ch!'t') p;

    auto s = "test";

    // 解析成功時。beginとsuccessが設定される
    assert(p(s));
    assert(s.front == 'e');
    assert(begin);
    assert(success);
    assert(!fail);

    reset();
}

/**
 *  抽象構文木
 *
 *  Params:
 *      T = ノードのタグの型
 */
class AST(T) {

    /// ノード
    static immutable class Node {
    
        /**
         *  位置・行番号・ノードの型を指定して生成する
         *
         *  Params:
         *      begin = 開始位置
         *      end = 終了位置
         *      line = 行番号
         *      type = ノードの型
         *      childlen = 子ノード
         */
        this(size_t begin, size_t end, size_t line, const(T) type, immutable(Node)[] children) @safe @nogc pure nothrow {
            this.begin_ = begin;
            this.end_ = end;
            this.line_ = line;
            this.type_ = type;
            this.children_ = children;
        }
    
        /// Returns: 開始位置
        @property size_t begin() @safe @nogc pure nothrow {return begin_;}
    
        /// Returns: 終了位置
        @property size_t end() @safe @nogc pure nothrow {return end_;}
    
        /// Returns: 行番号
        @property size_t line() @safe @nogc pure nothrow {return line_;}
    
        /// Returns: ノードの型
        @property T type() @safe @nogc pure nothrow {return type_;}
    
        /// Returns: 子ノード
        @property immutable(Node)[] children() @safe @nogc pure nothrow {return children_;}
    
    private:
    
        /// 開始位置
        size_t begin_;
    
        /// 終了位置
        size_t end_;
    
        /// 行番号
        size_t line_;
    
        /// ノードの型
        T type_;
    
        /// 子ノード
        Node[] children_;
    }

    /**
     *  ノードを開始する
     *
     *  Params:
     *      position = 開始位置
     *      line = 開始行
     *      type = 開始したノード
     */
    void beginNode(size_t position, size_t line, T type) @safe {
        stack_ ~= State(position, line, type, nodes_.length);
    }

    /**
     *  最後のノードを終了する
     *
     *  Params:
     *      position = 終了位置
     */
    void endNode(size_t position) @safe
    in {
        assert(stack_.length > 0);
    } body {
        auto state = stack_[$ - 1];
        auto node = new immutable(Node)(state.position, position, state.line, state.type, nodes_[state.nodeCount .. $]);
        nodes_.length = state.nodeCount;
        nodes_ ~= node;
        --stack_.length;
    }

    /**
     *  最後に開始したノードを元に戻す
     */
    void backtrack() @safe
    in {
        assert(stack_.length > 0);
    } body {
        auto state = stack_[$ - 1];
        nodes_.length = state.nodeCount;
        --stack_.length;
    }

    /**
     *  解析結果のルートノード
     *
     *  Returns:
     *      解析結果のルートノード
     */
    ref immutable(Node) root() @safe @nogc pure
    in {
        // 解析終了状態であること
        assert(stack_.length == 0 && nodes_.length == 1);
    } body {
        return nodes_[0];
    }

private:

    /// ノードの開始状態
    struct State {
        size_t position;
        size_t line;
        T type;
        size_t nodeCount;
    }

    /// 解析状態のスタック
    State[] stack_;

    /// 現在のノード列
    immutable(Node)[] nodes_;
}

///
unittest {
    // 適当なノードの型
    enum NodeType {
        NODE1,
        NODE2,
        NODE3,
    }

    auto ast = new AST!NodeType();

    // ノード1の開始
    ast.beginNode(0, 0, NodeType.NODE1);

    // ノード2の開始(ノード1の子ノード)
    ast.beginNode(1, 0, NodeType.NODE2);

    // ノード3の開始
    ast.beginNode(3, 1, NodeType.NODE3);

    // ノード3のバックトラック
    ast.backtrack();

    // ノード2の終了
    ast.endNode(3);

    // ノード2の2つ目の開始
    ast.beginNode(4, 1, NodeType.NODE2);

    // ノード2の2つ目の終了
    ast.endNode(5);

    // ノード1の終了
    ast.endNode(5);

    // ルートノードの取得
    auto root = ast.root;
    assert(root.type == NodeType.NODE1);
    assert(root.begin == 0);
    assert(root.line == 0);
    assert(root.children.length == 2);

    // ノード2の取得
    auto node2_1 = root.children[0];
    assert(node2_1.type == NodeType.NODE2);
    assert(node2_1.begin == 1);
    assert(node2_1.line == 0);
    assert(node2_1.children.length == 0);

    // ノード2の取得
    auto node2_2 = root.children[1];
    assert(node2_2.type == NodeType.NODE2);
    assert(node2_2.begin == 4);
    assert(node2_2.line == 1);
    assert(node2_2.children.length == 0);
}

