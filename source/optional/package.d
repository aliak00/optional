/**
    Home of the Optional type
*/
module optional;

///
unittest {
    // Create empty optional
    auto a = no!int;

    // Try doing stuff, all results in none
    assert(a == none);
    assert(++a == none);
    assert(a - 1 == none);

    // Assign and try doing the same stuff
    a = 9;
    assert(a == some(9));
    assert(++a == some(10));
    assert(a - 1 == some(9));

    // Acts like a range as well

    import std.algorithm: map;
    import std.conv: to;
    auto b = some(10);
    auto c = no!int;
    assert(b.map!(to!double).equal([10.0]));
    assert(c.map!(to!double).empty);

    // Can safely dispatch to whatever inner type is
    struct A {
        struct Inner {
            int g() { return 7; }
        }
        Inner inner() { return Inner(); }
        int f() { return 4; }
    }

    // Create Optional!A
    auto d = some(A());

    // Dispatch to one of its methods
    assert(d.dispatch.f == some(4));
    assert(d.dispatch.inner.g == some(7));

    auto e = no!(A*);

    // If there's no value in the optional dispatching still works, but produces none
    assert(e.dispatch.f == none);
    assert(e.dispatch.inner.g == none);
    e = new A;
    assert(e.dispatch.f == some(4));
    assert(e.dispatch.inner.g == some(7));
}

/// Phobos equvalent range.only test
unittest {
    import std.algorithm: filter, joiner, map;
    import std.uni: isUpper;

    assert(equal(some('♡'), "♡"));

    string title = "The D Programming Language";
    assert(title
        .filter!isUpper // take the upper case letters
        .map!some       // make each letter its own range
        .joiner(".")    // join the ranges together lazily
        .equal("T.D.P.L"));
}

import optional.internal;

public {
    import optional.optional;
    import optional.traits;
}