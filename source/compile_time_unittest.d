/**
 *  Authors: youxkei
 *      http://qiita.com/youxkei/items/24aabd5d5b65df0dc2e1
 */
module compile_time_unittest;

mixin template enableCompileTimeUnittest(string module_ = __MODULE__)
{
    static assert(
    {
        foreach(test; __traits(getUnitTests, mixin(module_)))
        {
            test();
        }
        return true;
    }());
}

