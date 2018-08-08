module tests.optional;

import optional.optional;
import unit_threaded;

import std.meta: AliasSeq;
import std.stdio: writeln;
import std.algorithm: equal;

alias QualifiedAlisesOf(T) = AliasSeq!(T, const T, immutable T);
alias OptionalsOfQualified(T) = AliasSeq!(Optional!T, Optional!(const T), Optional!(immutable T));
alias QualifiedOptionalsOfQualified(T) = AliasSeq!(QualifiedAlisesOf!(Optional!T), OptionalsOfQualified!T);


private enum isObject(T) = is(T == class) || is(T == interface);

import std.traits: Unqual;

import std.range, std.traits;

@("Should allow equalify with all qualifiers")
unittest {
    foreach (T; QualifiedOptionalsOfQualified!int) {
        auto a = T();
        auto b = T(3);
        auto c = T(4);
        a.should == none;
        b.should == b;
        b.should.not == c;
        c.should == 4;
    }
}

@("Should wotk with opUnary, opBinary, and opRightBinary")
unittest {
    import std.meta: AliasSeq;
    import std.traits: isMutable;
    import std.range: ElementType;
    foreach (T; QualifiedOptionalsOfQualified!int) {
        T a = 10;
        T b = none;
        static assert(!__traits(compiles, { int x = a; }));
        static assert(!__traits(compiles, { void func(int n){} func(a); }));
        a.should == 10;
        b.should == none;
        a.should.not == 20;
        a.should.not == none;
        (+a).should == some(10);
        (-b).should == none;
        (-a).should == some(-10);
        (+b).should == none;
        (-b).should == none;
        (a + 10).should == some(20);
        (b + 10).should == none;
        (a - 5).should == some(5);
        (b - 5).should == none;
        (a * 20).should == some(200);
        (b * 20).should == none;
        (a / 2).should == some(5);
        (b / 2).should == none;
        (10 + a).should == some(20);
        (10 + b).should == none;
        (15 - a).should == some(5);
        (15 - b).should == none;
        (20 * a).should == some(200);
        (20 * b).should == none;
        (50 / a).should == some(5);
        (50 / b).should == none;
        static if (isMutable!(ElementType!T) && isMutable!(T)) {
            (++a).should == some(11);
            (a++).should == some(11);
            a.should == some(12);
            (--a).should == some(11);
            (a--).should == some(11);
            a.should == some(10);
            a = a;
            a.should == some(10);
            a = 20;
            a.should == some(20);
        } else {
            static assert(!__traits(compiles, { ++a; }));
            static assert(!__traits(compiles, { a++; }));
            static assert(!__traits(compiles, { --a; }));
            static assert(!__traits(compiles, { a--; }));
            static assert(!__traits(compiles, { a = a; }));
            static assert(!__traits(compiles, { a = 20; }));
        }
    }
}

@("Should be mappable")
unittest {
    import std.algorithm: map;
    import std.conv: to;
    auto a = some(10);
    auto b = no!int;
    assert(a.map!(to!double).equal([10.0]));
    assert(b.map!(to!double).empty);
}

@("Should have opBinary return an optional")
unittest {
    auto a = some(3);
    assert(a + 3 == some(6));
    auto b = no!int;
    assert(b + 3 == none);
}


@("Should allow equality and opAssign between all qualified combinations")
unittest {
    import std.meta: AliasSeq;

    alias U = int;
    alias T = Optional!U;
    immutable U other = 4;

    alias Constructors = AliasSeq!(
        AliasSeq!(
            () => T(),
            () => const T(),
            () => immutable T(),
            () => T(U.init),
            () => const T(U.init),
            () => immutable T(U.init),
        ),
        AliasSeq!(
            () => no!U,
            () => no!(const U),
            () => no!(immutable U),
            () => some!U(U.init),
            () => some!(const U)(U.init),
            () => some!(immutable U)(U.init),
        )
    );

    static foreach (I; 0 .. 2) {{
        auto nm = Constructors[I * 6 + 0]();
        auto nc = Constructors[I * 6 + 1]();
        auto ni = Constructors[I * 6 + 2]();
        auto sm = Constructors[I * 6 + 3]();
        auto sc = Constructors[I * 6 + 4]();
        auto si = Constructors[I * 6 + 5]();

        assert(sm != nm);
        assert(sm != nc);
        assert(sm != ni);
        assert(sc != nm);
        assert(sc != nc);
        assert(sc != ni);
        assert(si != nm);
        assert(si != nc);
        assert(si != ni);

        assert(sm == sc);
        assert(sm == si);
        assert(sc == si);

        assert(nm == nc);
        assert(nm == ni);
        assert(nc == ni);

        sm = other;
        nm = other;
        assert(sm == nm);

        static assert( __traits(compiles, { nm = other; }));
        static assert(!__traits(compiles, { ni = other; }));
        static assert(!__traits(compiles, { nc = other; }));
        static assert( __traits(compiles, { sm = other; }));
        static assert(!__traits(compiles, { si = other; }));
        static assert(!__traits(compiles, { sc = other; }));

        static assert(is(typeof(nm.unwrap) == int*));
        static assert(is(typeof(nc.unwrap) == const(int)*));
        static assert(is(typeof(ni.unwrap) == immutable(int)*));
        static assert(is(typeof(sm.unwrap) == int*));
        static assert(is(typeof(sc.unwrap) == const(int)*));
        static assert(is(typeof(si.unwrap) == immutable(int)*));
    }}
}

@("Should unwrap the the correct qualified type for reference type")
unittest {
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

@("Should not allow properties of type to be reachable")
unittest {
    static assert(!__traits(compiles, some(3).max));
    static assert(!__traits(compiles, some(some(3)).max));
}

@("Should be filterable")
unittest {
    import std.algorithm: filter;
    import std.range: array;
    foreach (T; QualifiedOptionalsOfQualified!int) {
        const arr = [
            T(),
            T(3),
            T(),
            T(7),
        ];
        assert(arr.filter!(a => a != none).array == [some(3), some(7)]);
    }
}

@("Should print like a range")
unittest {
    assert(no!int.toString == "[]");
    assert(some(3).toString == "[3]");

    static class A {
        override string toString() { return "Yo"; }
    }
    Object a = new A;
    assert(some(cast(A)a).toString == "[Yo]");
    import std.algorithm: startsWith;
    assert(some(cast(immutable A)a).toString == "[Yo]");
}

@("Should be joinerable and eachable")
unittest {
    import std.uni: toUpper;
    import std.range: only;
    import std.algorithm: joiner, map, each;

    static maybeValues = [no!string, some("hello"), some("world")];
    assert(maybeValues.joiner.map!toUpper.joiner(" ").equal("HELLO WORLD"));

    static moreValues = [some("hello"), some("world"), no!string];
    uint count = 0;
    foreach (value; moreValues.joiner) ++count;
    assert(count == 2);
    moreValues.joiner.each!(value => ++count);
    assert(count == 4);
}

@("Should not allow assignment to const")
unittest {
    Optional!(const int) opt = Optional!(const int)(42);
    static assert(!__traits(compiles, opt = some(24)));
    static assert(!__traits(compiles, opt = none));
}

@("Should have correct unwrapped pointer type")
unittest {
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

@("Should treat null as valid values for pointer types")
unittest {
    auto a = no!(int*);
    auto b = *a;
    assert(a == no!(int*));
    assert(b == no!(int));
    b = 3;
    assert(b == some(3));
    a = null;
    assert(a == some!(int*)(null));
    assert(*a == no!int);
}

@("Should unwrap when there's a value")
unittest {
    struct S {
        int i = 1;
    }
    class C {
        int i = 1;
    }
    auto a = some!C(null);
    auto b = some!(S*)(null);

    assert(a.unwrap is null);
    assert(b.unwrap != null);
    assert(*b.unwrap == null);

    a = new C();
    bool aUnwrapped = false;
    if (auto c = a.unwrap) {
        aUnwrapped = true;
        assert(c.i == 1);
    }
    assert(aUnwrapped);

    b = new S();
    bool bUnwrapped = false;
    if (auto s = b.unwrap) {
        bUnwrapped = true;
        assert((*s).i == 1);
    }
    assert(bUnwrapped);

    auto c = no!int;
    assert(c.unwrap is null);
    c = some(3);
    bool cUnwrapped = false;
    if (auto p = c.unwrap) {
        cUnwrapped = true;
        assert(*p == 3);
    }
    assert(cUnwrapped);
}

@("Should allow 'is' on unwrap" )
unittest {
    class C {}
    auto a = no!C;
    auto b = some(new C);
    b = none;
    Optional!C c = null;
    auto d = some(new C);
    d = null;
    assert(a == none);
    assert(a.unwrap is null);
    assert(a.empty);
    assert(b == none);
    assert(b.unwrap is null);
    assert(b.empty);
    assert(c == none);
    assert(c.unwrap is null);
    assert(c.empty);
    assert(d == none);
    assert(d.unwrap is null);
    assert(d.empty);
}

@("Should not allow assignment to immutable")
unittest {
    auto a = some!(immutable int)(1);
    static assert(!__traits(compiles, { a = 2; }));
}

@("Should forward to opCall if callable")
unittest {
    static int f0(int) { return 4; }
    alias A = typeof(&f0);
    auto a0 = some(&f0);
    auto a1 = no!A;
    assert(a0(3) == some(4));
    assert(a1(3) == no!int);

    static void f1() {}
    alias B = typeof(&f1);
    auto b0 = some(&f1);
    auto b1 = no!B;
    static assert(is(typeof(b0()) == void));
    static assert(is(typeof(b1()) == void));
}

@("Should work with disabled this")
unittest {
    struct S {
        @disable this();
        this(int) {}
    }

    Optional!S a = none;
    static assert(__traits(compiles, { Optional!S a; }));
    auto b = some(S(1));
    auto c = b;
}

@("Should work with disabled post blit")
unittest {
    import std.conv: to;
    static struct S {
        int i;
        @disable this(this);
        this(int i) { this.i = i; }
    }

    auto a = Optional!S.construct(3);
    assert(a != none);
    assert(a.unwrap.i == 3);
}