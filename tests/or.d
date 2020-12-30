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
            assert(a.frontOr("x") == "hello");
            assert(t.frontOr('x') == 'w');
            assert(a.or(some(t)) == a);
            assert(t.or("x") == "world");
        }
    }
}

@("works with lambdas")
unittest {
    auto a = some("hello");
    auto b = no!string;
    assert(a.frontOr!(() => "world") == "hello");
    assert(b.frontOr!(() => "world") == "world");
    assert(a.or!(() => b) == a);
    assert(b.or!(() => a) == a);
}

@("works with strings")
unittest {
    assert((cast(string)null).frontOr('h') == 'h');
    assert("yo".frontOr('h') == 'y');
    assert("".frontOr('x') == 'x');
    assert((cast(string)null).or("hi") == "hi");
    assert("yo".or("hi") == "yo");
    assert("".or("x") == "x");
}

@("range to mapped and mapped to range")
unittest {
    import std.algorithm: map;
    auto r0 = [1, 2].or([1, 2].map!"a * 2");
    assert(r0.equal([1, 2]));
    auto r1 = (int[]).init.or([1, 2].map!"a * 2");
    assert(r1.equal([2, 4]));

    auto r2 = [1, 2].map!"a * 2".or([1, 2]);
    assert(r2.equal([2, 4]));
    auto r3 = (int[]).init.map!"a * 2".or([1, 2]);
    assert(r3.equal([1, 2]));
}

@("frontOr should work with Nullable")
unittest {
    import std.typecons: nullable;
    auto a = "foo".nullable;
    assert(a.frontOr("bar") == "foo");
    a.nullify;
    assert(a.frontOr("bar") == "bar");
}

@("or should work with Nullable")
unittest {
    import std.typecons: nullable, Nullable;
    auto a = "foo".nullable;
    auto b = Nullable!string();
    assert(a.or(b) == a.get);
    assert(b.or(a) == a.get);
}

@("should work with mapping")
unittest {
    import std.algorithm: map;
    import std.conv: to;
    auto a = [3].map!(to!string).or([""]);
    assert(a.equal(["3"]));
}

@("should work with two ranges")
unittest {
    import std.typecons: tuple;
    import std.algorithm: map;
    auto func() {
        return [1, 2, 3].map!(a => tuple(a, a));
    }
    assert(func().or(func()).equal(func()));
}

@("should work with class types")
unittest {
    static class C {}

    auto a = new C();
    auto b = new C();
    C c = null;

    assert(a.or(b) == a);
    assert(c.or(b) == b);
}

@("should work with void callbacks")
@nogc @safe unittest {
    int a = 0;
    auto b = no!int;
    b.or!(() => cast(void)(a = 3));
    assert(a == 3);
    b = 3;
    b.or!(() => cast(void)(a = 7));
    assert(a == 3);
}


@("should throw an OrElseException if the exception factory throws")
@safe unittest {
    import std.exception: assertThrown;

    int boo() {throw new Exception(""); }

    ""
        .frontOrThrow!(() { boo; return new Exception(""); } )
        .assertThrown!FrontOrThrowException;
}

@("Should throw exception if range empty")
@safe unittest {
    import std.exception: assertThrown, assertNotThrown;
    import std.range: iota;

    0.iota(0)
        .frontOrThrow(new Exception(""))
        .assertThrown!Exception;

    0.iota(1)
        .frontOrThrow(new Exception(""))
        .assertNotThrown!Exception;
}

@("Should throw if nullable isNull")
@safe unittest {
    import std.exception: assertThrown, assertNotThrown;
    import std.typecons: nullable;

    auto a = "foo".nullable;

    a.frontOrThrow(new Exception(""))
        .assertNotThrown!Exception;

    a.nullify;

    a.frontOrThrow(new Exception(""))
        .assertThrown!Exception;
}

@("or should work with rhs or lhs of null")
unittest {
    auto a = "hello".or(null);
    auto b = null.or("hello");
    assert(a == "hello");
    assert(b == "hello");

    auto c = "".or(null);
    auto d = null.or("");
    assert(c == null);
    assert(d == "");
}

@("Should work with optional chains")
@safe unittest {
    import optional: oc;
    static class Class {
        int i;
        this(int i) {
            this.i = i;
        }
    }

    auto a = no!Class;
    auto b = some(new Class(3));

    const x = oc(a).i.frontOr(7);
    const y = oc(b).i.frontOr(7);

    assert(x == 7);
    assert(y == 3);
}
