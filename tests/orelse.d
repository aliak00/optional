module tests.orelse;

import optional;
import std.algorithm.comparison: equal;

@("works with qualified optionals")
unittest {
    import std.meta: AliasSeq;
    alias T = string;
    foreach (U; AliasSeq!(T, const T, immutable T)) {
        foreach (V; AliasSeq!(Optional!T, const Optional!T, immutable Optional!T)) {
            V a = some("hello");
            T t = "world";
            assert(a.frontOrElse("x") == "hello");
            assert(t.frontOrElse('x') == 'w');
            assert(a.orElse(some(t)) == a);
            assert(t.orElse("x") == "world");
        }
    }
}

@("works with lambdas")
unittest {
    auto a = some("hello");
    auto b = no!string;
    assert(a.frontOrElse!(() => "world") == "hello");
    assert(b.frontOrElse!(() => "world") == "world");
    assert(a.orElse!(() => b) == a);
    assert(b.orElse!(() => a) == a);
}

@("works with strings")
unittest {
    assert((cast(string)null).frontOrElse('h') == 'h');
    assert("yo".frontOrElse('h') == 'y');
    assert("".frontOrElse('x') == 'x');
    assert((cast(string)null).orElse("hi") == "hi");
    assert("yo".orElse("hi") == "yo");
    assert("".orElse("x") == "x");
}

@("range to mapped and mapped to range")
unittest {
    import std.algorithm: map;
    auto r0 = [1, 2].orElse([1, 2].map!"a * 2");
    assert(r0.equal([1, 2]));
    auto r1 = (int[]).init.orElse([1, 2].map!"a * 2");
    assert(r1.equal([2, 4]));

    auto r2 = [1, 2].map!"a * 2".orElse([1, 2]);
    assert(r2.equal([2, 4]));
    auto r3 = (int[]).init.map!"a * 2".orElse([1, 2]);
    assert(r3.equal([1, 2]));
}

@("frontOrElse should work with Nullable")
unittest {
    import std.typecons: nullable;
    auto a = "foo".nullable;
    assert(a.frontOrElse("bar") == "foo");
    a.nullify;
    assert(a.frontOrElse("bar") == "bar");
}

@("orElse should work with Nullable")
unittest {
    import std.typecons: nullable, Nullable;
    auto a = "foo".nullable;
    auto b = Nullable!string();
    assert(a.orElse(b) == a);
    assert(b.orElse(a) == a);
}

@("should work with mapping")
unittest {
    import std.algorithm: map;
    import std.conv: to;
    auto a = [3].map!(to!string).orElse([""]);
    assert(a.equal(["3"]));
}

@("should work with two ranges")
unittest {
    import std.typecons: tuple;
    import std.algorithm: map;
    auto func() {
        return [1, 2, 3].map!(a => tuple(a, a));
    }
    assert(func().orElse(func()).equal(func()));
}

@("should work with class types")
unittest {
    static class C {}

    auto a = new C();
    auto b = new C();
    C c = null;

    assert(a.orElse(b) == a);
    assert(c.orElse(b) == b);
}

@("should work with void callbacks")
@nogc @safe unittest {
    int a = 0;
    auto b = no!int;
    b.orElse!(() => cast(void)(a = 3));
    assert(a == 3);
    b = 3;
    b.orElse!(() => cast(void)(a = 7));
    assert(a == 3);
}
