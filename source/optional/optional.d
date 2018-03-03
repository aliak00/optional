/**
    Optional type
*/
module optional.optional;

import optional.internal;

private struct None {}

/**
    Represents an empty optional value. This is used to set `Optional`s to have no value
    or for comparisons

    SeeAlso:
        - `Optional.opEquals`
*/
immutable none = None();

/**
    Optional type. Also known as a Maybe type in some languages.

    This can either contain a value or be empty. It works with any value, including
    values that can be null. I.e. null is a valid value that can be contained inside
    an optional if T is a pointer type (or nullable)

    It also has range like behavior. So this acts as a range that contains 1 element or
    is empty.

    All operations that can be performed on a T can also be performed on an Optional!T.
    The behavior of applying an operation on a no value or a null pointer is well defined
    and safe.
*/
struct Optional(T) {
    import std.traits: isPointer, hasMember;
    import std.range: hasAssignableElements;

    T[] bag;

    this(U)(U u) pure {
        this.bag = [u];
    }
    this(None) pure {
        this.bag = [];
    }
    this(this) pure {
        this.bag = this.bag.dup;
    }

    @property bool empty() const {
        return this.bag.length == 0;
    }
    @property auto ref front() inout {
        return this.bag[0];
    }
    void popFront() {
        this.bag = [];
    }

    static if (hasAssignableElements!(T[]))
    {
        /// Sets value to some `t` or `none`
        void opAssign(T t) {
            if (this.empty) {
                this.bag = [t];
            } else {
                this.bag[0] = t;
            }
        }
    }

    /// Ditto
    void opAssign(None _) {
        this.bag = [];
    }

    /**
        Compare two optionals or an optional with some value

        Returns:
            - If the two are optionals then they are both unwrapped and compared. If either are empty 
            this returns false. And if compared with `none` and there's a value, also returns false

        ---
        auto a = some(3);
        a == some(2); // false
        a == some(3); // true
        a == none; // false
        ---
    */
    bool opEquals(U : T)(auto ref Optional!U rhs) const {
        return this.bag == rhs.bag;
    }

    /// Ditto
    bool opEquals(None _) const {
        return this.bag.length == 0;
    }

    /// Ditto
    bool opEquals(U : T)(const auto ref U rhs) const {
        return !empty && front == rhs;
    }

    /**
        Applies unary operator to internal value of optional.

        Returns:
            - If the optional is some value it returns an optional of some `op value`.

        ---
        auto a = no!(int*);
        auto b = *a; // ok
        b = 3; // b is an Optional!int because of the deref
        ---
    */
    auto opUnary(string op)() const if (op != "++" && op != "--") {
        static if (op == "*" && isPointer!T)
        {
            import std.traits: PointerTarget;
            alias P = PointerTarget!T;
            return empty || front is null ? no!P : some!P(*front);
        }
        else
        {
            if (empty) {
                return no!T;
            } else {
                auto val = mixin(op ~ "front");
                return some!T(val);
            }
        }
    }

    /// Ditto
    auto opUnary(string op)() if (op == "++" || op == "--") {
        return empty ? no!T : some!T(mixin(op ~ "front"));
    }

    /**
        If the optional is some value it returns an optional of some `value op rhs`
    */
    auto ref opBinary(string op, U : T)(auto ref U rhs) const {
        return empty ? no!T : some!T(mixin("front"  ~ op ~ "rhs"));
    }

    /**
        If the optional is some value it returns an optional of some `rhs op value`
    */
    auto ref opBinaryRight(string op, U : T)(auto ref U rhs) const {
        return empty ? no!T : some!T(mixin("rhs"  ~ op ~ "front"));
    }

    /**
        Allows you to call dot operator on the internal value if present

        If there is no value inside, or it is null, dispatching will still work but will
        produce a series of noops.

        If you try and call a manifest constant or static data on T then whether the manifest
        or static immutable data is called depends on if the instance it is called on is a
        some or a none.

        Returns:
            A proxy to T that is aliased to an Optional!T. This means that all dot operations
            are dispatched to T if there is a T and operator support is carried out by aliasing
            to Optional!T.

            To cast back to an Optional!T you can call `some(Optional!(T).dispatch)`

        ---
        struct A {
            struct Inner {
                int g() { return 7; }
            }
            Inner inner() { return Inner(); }
            int f() { return 4; }
        }
        auto a = some(A());
        auto b = no!A;
        auto b = no!(A*);
        a.dispatch.inner.g; // calls inner and calls g
        b.dispatch.inner.g; // no op.
        b.dispatch.inner.g; // no op.
        ---
    */
    auto dispatch() {
        import std.typecons: Yes;
        import optional.dispatcher;
        return OptionalDispatcher!(T, Yes.refOptional)(&this);
    }
    static if (is(T == class))
    {
        /**
            Get pointer to value. If T is a reference type then T is returned

            Use this to safely access reference types, or to get at the raw value
            of non reference types via a non-null pointer.

            Returns:
                Pointer to value or null if empty. If T is reference type, returns reference
        */
        inout T unwrap() const {
            return this.empty || (front is null) ? null : cast(T)front;
        }
    }
    else
    {
        /// Ditto
        inout T* unwrap() const {
            return this.empty ? null : cast(T*)&this.bag[0];
        }
    }

    /// Converts value to string `"some(T)"` or `"no!T"`
    string toString() {
        import std.conv: to;
        if (this.bag.length == 0) {
            return "no!" ~ T.stringof;
        }
        // TODO: UFCS on front.to does not work here.
        return "some!" ~ T.stringof ~ "(" ~ to!string(front) ~ ")";
    }
}

/**
    Type constructor for an optional having some value of `T`

    Calling some on the result of a dispatch chain will result
    in the original optional value.
*/
auto some(T)(T t) {
    import optional.dispatcher: OptionalDispatcher;
    static if (is(T U : OptionalDispatcher!(U)))
    {
        return t.self;
    }
    else
    {
        return Optional!T(t);
    }
}

///
unittest {
    auto a = no!int;
    assert(a == none);
    a = 9;
    assert(a == some(9));
    assert(a != none);

    import std.algorithm: map;
    assert([1, 2, 3].map!some.array == [some(1), some(2), some(3)]);
}

unittest {
    class C {
        int i = 0;
        C mutate() {
            this.i++;
            return this;
        }
    }

    auto a = some(new C());
    auto b = a.dispatch.mutate.mutate.mutate;

    // Unwrap original should have mutated the object
    assert(a.unwrap.i == 3);

    // some(Dispatcher result) should be original Optional type
    static assert(is(typeof(b.some) == Optional!C));
    assert(b.some.unwrap.i == 3);
}

/// Type constructor for an optional having no value of `T`
auto no(T)() {
    return Optional!T();
}

///
unittest {
    auto a = no!(int*);
    assert(*a != 9);
    a = new int(9);
    assert(*a == 9);
    assert(a != none);
    a = null;
    assert(a != none);
}

unittest {
    import std.meta: AliasSeq;
    import std.conv: to;
    import std.algorithm: map;
    foreach (T; AliasSeq!(Optional!int, const Optional!int, immutable Optional!int)) {
        T a = 10;
        T b = none;
        static assert(!__traits(compiles, { int x = a; }));
        static assert(!__traits(compiles, { void func(int n){} func(a); }));
        assert(a == 10);
        assert(b == none);
        assert(a != 20);
        assert(a != none);
        assert(+a == some(10));
        assert(-b == none);
        assert(-a == some(-10));
        assert(+b == none);
        assert(-b == none);
        assert(a + 10 == some(20));
        assert(b + 10 == none);
        assert(a - 5 == some(5));
        assert(b - 5 == none);
        assert(a * 20 == some(200));
        assert(b * 20 == none);
        assert(a / 2 == some(5));
        assert(b / 2 == none);
        assert(10 + a == some(20));
        assert(10 + b == none);
        assert(15 - a == some(5));
        assert(15 - b == none);
        assert(20 * a == some(200));
        assert(20 * b == none);
        assert(50 / a == some(5));
        assert(50 / b == none);
        static if (is(T == Optional!int))  // mutable
        {
            assert(++a == some(11));
            assert(a++ == some(11));
            assert(a == some(12));
            assert(--a == some(11));
            assert(a-- == some(11));
            assert(a == some(10));
            a = a;
            assert(a == some(10));
            a = 20;
            assert(a == some(20));
        }
    }
}

unittest {
    import std.algorithm: map;
    import std.conv: to;
    auto a = some(10);
    auto b = no!int;
    assert(a.map!(to!double).equal([10.0]));
    assert(b.map!(to!double).empty);
}

unittest {
    auto a = some(3);
    assert(a + 3 == some(6));
    auto b = no!int;
    assert(b + 3 == none);
}

unittest {
    auto n = no!(int);
    auto nc = no!(const int);
    auto ni = no!(immutable int);
    auto o = some!(int)(3);
    auto oc = some!(const int)(3);
    auto oi = some!(immutable int)(3);

    assert(o != n);
    assert(o != nc);
    assert(o != ni);
    assert(oc != n);
    assert(oc != nc);
    assert(oc != ni);
    assert(oi != n);
    assert(oi != nc);
    assert(oi != ni);

    assert(o == oc);
    assert(o == oi);
    assert(oc == oi);

    assert(n == nc);
    assert(n == ni);
    assert(nc == ni);

    o = 4;
    n = 4;
    assert(o == n);

    static assert( is(typeof(n = 3)));
    static assert(!is(typeof(ni = 3)));
    static assert(!is(typeof(nc = 3)));
    static assert( is(typeof(o = 3)));
    static assert(!is(typeof(oi = 3)));
    static assert(!is(typeof(oc = 3)));
}

unittest {
    static assert(!__traits(compiles, some(3).max));
    static assert(!__traits(compiles, some(some(3)).max));
}

unittest {
    import std.algorithm: filter;
    import std.range: array;
    const arr = [
        no!int,
        some(3),
        no!int,
        some(7),
    ];
    assert(arr.filter!(a => a != none).array == [some(3), some(7)]);
}

unittest {
    assert(no!int.toString == "no!int");
    assert(some(3).toString == "some!int(3)");
    static class A {
        override string toString() { return "A"; }
    }
    Object a = new A;
    assert(some(cast(A)a).toString == "some!A(A)");
}

unittest {
    import std.uni: toUpper;
    import std.range: only;
    import std.algorithm: joiner, map;

    static maybeValues = [no!string, some("hello"), some("world")];
    assert(maybeValues.joiner.map!toUpper.joiner(" ").equal("HELLO WORLD"));
}

unittest {
    import std.algorithm.iteration : each, joiner;
    static maybeValues = [some("hello"), some("world"), no!string];
    uint count = 0;
    foreach (value; maybeValues.joiner) ++count;
    assert(count == 2);
    maybeValues.joiner.each!(value => ++count);
    assert(count == 4);
}

unittest {
    Optional!(const int) opt = Optional!(const int)(42);
    static assert(!__traits(compiles, opt = some(24)));
    assert(!opt.empty);
    assert(opt.front == 42);
    opt = none;
    assert(opt.empty);
}

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
    static assert(!__traits(compiles, *uic = 4));

    static assert(is(typeof(uoc) == const(int)*));
    static assert(is(typeof(uoi) == immutable(int)*));

    assert(o == some(4));
}

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