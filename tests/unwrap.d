module tests.unwrap;

import optional;

@("Should work with qualified optionals")
unittest {
    import std.meta: AliasSeq;
    foreach (T; AliasSeq!(Optional!int, const Optional!int, immutable Optional!int)) {
        T a = some(3);
        assert(a.unwrap !is null);
    }
}

@("Should unwrap to the correct qualified type for reference type")
@safe unittest {
    static class C {}
    auto nm = no!(C);
    auto nc = no!(const C);
    auto ni = no!(immutable C);
    auto sm = some(new C);
    auto sc = some(new const C);
    auto si = some(new immutable C);

    static assert(is(typeof(nm.unwrap) == C));
    static assert(is(typeof(nc.unwrap) == const(C)));
    static assert(is(typeof(ni.unwrap) == immutable(C)));
    static assert(is(typeof(sm.unwrap) == C));
    static assert(is(typeof(sc.unwrap) == const(C)));
    static assert(is(typeof(si.unwrap) == immutable(C)));
}

@("Should have correct unwrapped pointer type")
@nogc unittest {
    auto n = no!(int);
    auto nc = no!(const int);
    auto ni = no!(immutable int);
    auto o = some!(int)(3);
    auto oc = some!(const int)(3);
    auto oi = some!(immutable int)(3);

    assert(n.unwrap == null);
    assert(nc.unwrap == null);
    assert(ni.unwrap == null);

    auto uo = o.unwrap;
    auto uoc = oc.unwrap;
    auto uoi = oi.unwrap;

    assert(uo != null);
    assert(uoc != null);
    assert(uoi != null);

    assert(*uo == 3);
    assert(*uoc == 3);
    assert(*uoi == 3);

    *uo = 4;
    assert(o == some(4));

    static assert(!__traits(compiles, *uoc = 4));
    static assert(!__traits(compiles, *uoi = 4));

    static assert(is(typeof(uoc) == const(int)*));
    static assert(is(typeof(uoi) == immutable(int)*));

    assert(o == some(4));
}
