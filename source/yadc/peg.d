module yadc.peg;

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
        auto s = src.save;
        scope(exit) src = s;
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
        auto s = src.save;
        scope(exit) src = s;
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
    bool seq(R)(ref R src) {
        auto s = src.save;
        foreach(p; P) {
            if(!p(src)) {
                src = s;
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
    bool sel(R)(ref R src) {
        auto s = src.save;
        foreach(p; P) {
            if(p(src)) {
                return true;
            }
        }
        return false;
    }
}

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

