module tests.tooptional;

import optional;

@("works with Nullable")
unittest {
    import std.typecons: nullable;
    auto a = 3.nullable;
    assert(a.toOptional == some(3));
    a.nullify;
    assert(a.toOptional == no!int);
}

@("works with other ranges")
unittest {
    import std.algorithm: map;
    assert([1].map!(r => r).toOptional == some(1));
}
