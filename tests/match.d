module tests.match;

import optional;

@("Should work with qualified optionals")
unittest {
    import std.meta: AliasSeq;
    foreach (T; AliasSeq!(Optional!int, const Optional!int, immutable Optional!int)) {
        T a = some(3);
        auto r = a.match!(
            (int a) => "yes",
            () => "no",
        );
        assert(r == "yes");
    }
}
