/**
    Home of the `Optional` type
*/
module optional;

///
@("Example 1")
unittest {
    import std.algorithm: equal;

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
    assert(b.frontOr(3) == 10);
    assert(c.frontOr(3) == 3);

    // Unwrap to get to the raw data (returns a non-null pointer or reference if there's data)
    class C {
        int i = 3;
    }

    auto n = no!C;
    n.or!(() => n = some!C(null));
    assert(n == none);
    n.or!(() => n = new C());
    assert(n.front !is null);
    assert(n.front.i == 3);
}

/// Phobos equvalent range.only test
@("Example 2")
unittest {
    import std.algorithm: filter, joiner, map, equal;
    import std.uni: isUpper;

    assert(equal(some('♡'), "♡"));

    string title = "The D Programming Language";
    assert(title
        .filter!isUpper // take the upper case letters
        .map!some       // make each letter its own range
        .joiner(".")    // join the ranges together lazily
        .equal("T.D.P.L"));
}

public {
    import optional.optional;
    import optional.traits;
    import optional.oc;
    import optional.or;
    import optional.match;
}
