module optional.internal;

version (unittest) {
    package import std.stdio;
    package import std.algorithm.comparison: equal;
}

template from(string moduleName) {
    mixin("import from = " ~ moduleName ~ ";");
}
