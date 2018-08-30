/**
    Home of the `Optional` type, faaturing the `NotNull` type
*/
module optional;

///
@("Example 1")
unittest {
    // Create empty optional
    auto a = no!int;

    // Operating on an empty optional is safe and results in none
    assert(a == none);
    assert(++a == none);

    // Assigning a value and then operating yields results
    a = 9;
    assert(a == some(9));
    assert(++a == some(10));

    // It is a range
    import std.algorithm: map;
    auto b = some(10);
    auto c = no!int;
    assert(b.map!(a => a * 2).equal([20]));
    assert(c.map!(a => a * 2).empty);

    // Safely get the inner value
    assert(b.orElse(3) == 10);
    assert(c.orElse(3) == 3);

    // Unwrap to get to the raw data (returns a non-null pointer or reference if there's data)
    class C {
        int i = 3;
    }

    auto n = no!C;
    if (auto u = n.unwrap) {} else n = some!C(null);
    assert(n == none);
    if (auto u = n.unwrap) {} else n = new C();
    assert(n.unwrap !is null);
    assert(n.unwrap.i == 3);

    // Safely dispatch calls to the wrapped type
    struct A {
        struct Inner {
            int g() { return 7; }
        }
        Inner inner() { return Inner(); }
        int f() { return 4; }
    }
    auto d = some(A());
    assert(d.dispatch.f == some(4));
    assert(d.dispatch.inner.dispatch.g == some(7));

    // If there's no value in the optional dispatching still works, but produces none
    auto e = no!(A*);
    assert(e.dispatch.f == none);
    assert(e.dispatch.inner.dispatch.g == none);
}

/// Phobos equvalent range.only test
@("Example 2")
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
    import optional.notnull;
    import optional.safederef;
}
