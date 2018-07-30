/**
    Optional type
*/
module optional.optional;

import optional.internal;

import optional.dispatcher: Dispatcher; // for orElse that takes a Dispatcher, could not use 'from' template for some reason

private struct None {}

/**
    Represents an empty optional value. This is used to set `Optional`s to have no value
    or for comparisons

    SeeAlso:
        - `Optional.opEquals`
*/
immutable none = None();

/**
    Optional type. Also known as a Maybe or Option type in some languages.

    This can either contain a value or be `none`. It works with any value, including
    values that can be null. I.e. null is a valid value that can be contained inside
    an optional if T is a pointer type

    It also has range like behavior. So this acts as a range that contains 1 element or
    is empty. Similar to `std.algorithm.only`

    And all operations that can be performed on a T can also be performed on an Optional!T.
    The behavior of applying an operation on a no-value or null pointer is well defined
    and safe.
*/

struct Optional(T) {
    import std.traits: isMutable, isSomeFunction, isAssignable, Unqual;

    private enum isNullInvalid = is(T == class) || is(T == interface) || isSomeFunction!T;
    private enum isNullable = is(typeof(T.init is null));

    private T _value = T.init; // Set to init for when T has @disable this()
    private bool _empty = true;

    private static string autoReturn(string call) {
        return
            "alias R = typeof(" ~ call ~ ");" ~
            "static if (!is(R == void))" ~
                "return empty ? no!R : some(" ~ call ~ ");" ~
            "else {" ~
                "if (!empty) {" ~
                    call ~ ";" ~
                "}" ~
            "}";
    }

    private enum setEmpty = q{
        static if (isNullInvalid) {
            this._empty = this._value is null;
        } else {
            this._empty = false;
        }
    };
    private void setEmptyState() {
        mixin(setEmpty);
    }

    /**
        Allows you to create an Optional type in place.

        This is useful if type T has a @disable this(this) for e.g.
    */
    static Optional!T construct(Args...)(auto ref Args args) {
        import std.algorithm: move;
        auto value = T(args);
        Optional!T opt;
        opt._value = move(value);
        opt.setEmptyState;
        return move(opt);
    }

    /**
        Constructs an Optional!T value by assigning T

        If T is of class type, interface type, or some function pointer than passing in null
        sets the optional to `none` interally

    */
    this(U : T, this This)(auto ref U value) {
        this._value = value;
        mixin(setEmpty);
    }
    /// Ditto
    this(const None) pure {
        // For Error: field _value must be initialized in constructor, because it is nested struct
        this._value = T.init;
    }

    @property bool empty() const { 
        static if (isNullInvalid) {
            return this._empty || this._value is null;
        } else {
            return this._empty;
        }
    }
    @property ref inout(T) front() inout { return this._value; }
    void popFront() { this._empty = true; }

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
    bool opEquals(const None) const { return this.empty; }
    /// Ditto
    bool opEquals(U : T)(const auto ref Optional!U rhs) const {
        if (this.empty || rhs.empty) return this.empty == rhs.empty;
        return this._value == rhs._value;
    }
    /// Ditto
    bool opEquals(U : T)(const auto ref U rhs) const {
        return !this.empty && this._value == rhs;
    }

    /**
        Assigns a value to the optional or sets it to `none`.

        If T is of class type, interface type, or some function pointer than passing in null
        sets the optional to `none` internally
    */
    void opAssign()(const None) if (isMutable!T) {
        if (!this.empty) {
            destroy(this._value);
            this._empty = true;
        }
    }
    void opAssign(U)(auto ref U lhs) if (isMutable!T && isAssignable!(T, U)) {
        this._value = lhs;
        mixin(setEmpty);
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
    auto ref opUnary(string op, this This)() {
        import std.traits: isPointer;
        static if (op == "*" && isPointer!T) {
            import std.traits: PointerTarget;
            alias P = PointerTarget!T;
            return empty || front is null ? no!P : some(*this.front);
        } else {
            mixin(autoReturn(op ~ "front"));
        }
    }

    /**
        If the optional is some value it returns an optional of some `value op rhs`
    */
    auto ref opBinary(string op, U : T)(auto ref U rhs) inout {
        mixin(autoReturn("front" ~ op ~ "rhs"));
    }
    /**
        If the optional is some value it returns an optional of some `lhs op value`
    */
    auto ref opBinaryRight(string op, U : T)(auto ref U lhs) inout {
        mixin(autoReturn("lhs"  ~ op ~ "front"));
    }

    /**
        If there's a value that's callable it will be called else it's a noop

        Returns:
            Optional value of whatever `T(args)` returns
    */
    auto ref opCall(Args...)(Args args) if (from!"std.traits".isCallable!T) {
        mixin(autoReturn(q{ this._value(args) }));
    }

    /// Converts value to string
    string toString() const {
        import std.conv: to; import std.traits;
        if (empty) {
            return "[]";
        }
        // Cast to unqual if we can copy so writing it out does the right thing.
        static if (isCopyable!T) {
            immutable str = to!string(cast(Unqual!T)this._value);
        } else {
            immutable str = to!string(this._value);
        }
        return "[" ~ str ~ "]";
    }

    /**
        Allows you to call dot operator on the internal value if present
        If there is no value inside, or it is null, dispatching will still work but will
        produce a series of no-ops.

        If you try and call a manifest constant or static data on T then whether the manifest
        or static immutable data is called depends on if the instance it is called on is a
        some or a none.

        Returns:
            A proxy `Dispatcher` to T that is aliased to an Optional!T. This means that all dot operations
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
    auto dispatch() inout {
        import optional.dispatcher: Dispatcher;
        return inout Dispatcher!(T)(&this);
    }
}

version (unittest) {
    import std.meta: AliasSeq;
    alias QualifiedAlisesOf(T) = AliasSeq!(T, const T, immutable T);
    alias OptionalsOfQualified(T) = AliasSeq!(Optional!T, Optional!(const T), Optional!(immutable T));
    alias QualifiedOptionalsOfQualified(T) = AliasSeq!(QualifiedAlisesOf!(Optional!T), OptionalsOfQualified!T);
    import std.stdio: writeln;
}

unittest {
    foreach (T; QualifiedOptionalsOfQualified!int) {
        auto a = T();
        auto b = T(3);
        auto c = T(4);
        assert(a == none);
        assert(b == b);
        assert(b != c);
        assert(c == 4);
    }
}

/**
    Type constructor for an optional having some value of `T`

    Calling some on the result of a dispatch chain will result
    in the original optional value.
*/
auto ref some(T)(auto ref T value) {
    import optional.traits: isDispatcher;
    static if (isDispatcher!T) {
        return value.self;
    } else {
        return Optional!T(value);
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
    assert([1, 2, 3].map!some.equal([some(1), some(2), some(3)]));
}

unittest {
    struct S {
        int f() { return 3; }
    }

    static assert(is(typeof(some(S()).dispatch.some) == Optional!S));
}

/// Type constructor for an optional having no value of `T`
auto no(T)() {
    return Optional!T();
}

///
unittest {
    auto a = no!(int*);
    assert(a == none);
    assert(*a != 9);
    a = new int(9);
    assert(*a == 9);
    assert(a != none);
    a = null;
    assert(a != none);
}

/**
    Get pointer to value. If T is a reference type then T is returned

    Use this to safely access reference types, or to get at the raw value
    of non reference types via a non-null pointer.

    It is recommended that you access internal values by using `orElse` instead though

    Returns:
        Pointer to value or null if empty. If T is reference type, returns reference
*/
auto ref unwrap(T)(auto ref T opt) if (from!"optional.traits".isOptional!T) {
    import optional.traits: OptionalTarget;
    alias U = OptionalTarget!T;
    static if (is(U == class) || is(U == interface)) {
        return opt.empty ? null : opt.front;
    } else {
        return opt.empty ? null : &opt.front();
    }
}

/**
    Returns the value contained within the optional _or else_ another value if there's `no!T`

    Can also be called at the end of a `dispatch` chain
*/
T orElse(T)(Optional!T opt, auto ref T value) {
    return opt.empty ? value : opt.front;
}

/// Ditto
T orElse(T)(Dispatcher!T dispatchedOptional, auto ref T value) {
    return some(dispatchedOptional).orElse(value);
}

///
unittest {
    assert(some(3).orElse(9) == 3);
    assert(no!int.orElse(9) == 9);

    struct S {
        int g() { return 3; }
    }

    assert(some(S()).dispatch.g.some.orElse(9) == 3);
    assert(no!S.dispatch.g.some.orElse(9) == 9);

    class C {
        int g() { return 3; }
    }

    assert(some(new C()).dispatch.g.orElse(9) == 3);
    assert(no!C.dispatch.g.orElse(9) == 9);
}

unittest {
    import std.meta: AliasSeq;
    import std.traits: isMutable;
    import std.range: ElementType;
    foreach (T; QualifiedOptionalsOfQualified!int) {
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
        static if (isMutable!(ElementType!T) && isMutable!(T)) {
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

unittest {
    static assert(!__traits(compiles, some(3).max));
    static assert(!__traits(compiles, some(some(3)).max));
}

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
    static assert(!__traits(compiles, opt = none));
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
    static assert(!__traits(compiles, *uoi = 4));

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

unittest {
    auto a = some!(immutable int)(1);
    static assert(!__traits(compiles, { a = 2; }));
}

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
