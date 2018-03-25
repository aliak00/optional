module optional.internal;

version (unittest) {
    public import std.stdio;
    public import std.algorithm.comparison: equal;
}

template from(string moduleName) {
    mixin("import from = " ~ moduleName ~ ";");
}
