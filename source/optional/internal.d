module optional.internal;

version (unittest) {
    public import std.stdio;
    public import std.algorithm.comparison: equal;
    public import std.array;
    public import optional;
}

template from(string moduleName) {
    mixin("import from = " ~ moduleName ~ ";");
}
