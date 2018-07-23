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
    an optional if T is a pointer type

    It also has range like behavior. So this acts as a range that contains 1 element or
    is empty.

    All operations that can be performed on a T can also be performed on an Optional!T.
    The behavior of applying an operation on a no value or a null pointer is well defined
    and safe.
*/

struct Optional(T) {
    import std.traits: isMutable, isSomeFunction, isAssignable, Unqual;

    private enum isNullInvalid = is(T == class) || is(T == interface) || isSomeFunction!T;
    private enum isNullable = is(typeof(T.init is null));

    private T _value;
    private bool _empty = true;

    private enum setEmpty = q{
        static if (isNullInvalid) {
            this._empty = this._value is null;
        } else {
            this._empty = false;
        }
    };

    /**
        Constructs an Optional!T value either by assigning T or forwarding to T's constructor
        if possible.

        If T is of class type, interface type, or some function pointer than passing in null
        sets the optional to `none` interally

    */
    this(U : T)(auto ref inout(U) value) inout {
        this._value = value;
        mixin(setEmpty);
    }
    /// Ditto
    this(const None) pure {}

    @property bool empty() const { 
        static if (isNullInvalid) {
            return this._empty || this._value is null;
        } else {
            return this._empty;
        }
    }
    @property inout(T) front() inout { return this._value; }
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

    static if (isMutable!T) {
        /**
            Assigns a value to the optional or sets it to `none`.

            If T is of class type, interface type, or some function pointer than passing in null
            sets the optio optional to `none` internally
        */
        void opAssign(const None) {
            if (!this.empty) {
                destroy(this._value);
                this._empty = true;
            }
        }
        void opAssign(U)(auto ref U lhs) if (isAssignable!(T, U)) {
            this._value = lhs;
            mixin(setEmpty);
        }
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
    auto opUnary(string op)() const {
        import std.traits: isPointer;
        static if (op == "*" && isPointer!T) {
            import std.traits: PointerTarget;
            alias P = PointerTarget!T;
            return empty || front is null ? no!P : some(cast(P)*_value);
        } else {
            if (empty) {
                return no!T;
            } else {
                T newValue = mixin(op ~ "_value");
                return some(newValue);
            }
        }
    }
    /// Ditto
    auto opUnary(string op)() if (isMutable!T && (op == "++" || op == "--")) {
        return empty ? no!T : some(mixin(op ~ "_value"));
    }

    // Converts value to string `"some(T)"` or `"no!T"`
    string toString() const {
        import std.conv: to; import std.traits;
        if (empty) {
            return "[]";
        }
        return "[" ~ to!string(cast(T)this._value) ~ "]";
    }
}

version (unittest) {
    alias QualifiedAlisesOf(T) = from!"std.meta".AliasSeq!(T, const T, immutable T);
    import std.stdio: writeln;
}

unittest {
    foreach (T; QualifiedAlisesOf!(Optional!int)) {
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
auto some(T)(auto ref inout(T) value) {
    return inout(Optional!T)(value);
}
/// Ditto
auto some(T)(auto ref const(T) value) {
    return Optional!T(cast(T)value);
}

// auto some(T)(T value) {
//     import optional.dispatcher: OptionalDispatcher;
//     static if (is(T : OptionalDispatcher!P, P...))
//     {
//         static if (P[1]) // refOptional
//         {
//             return *value.self;
//         }
//         else
//         {
//             return value.self;
//         }
//     }
//     else
//     {
//         return Optional!T(value);
//     }
// }

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

/// Type constructor for an optional having no value of `T`
Optional!T no(T)() {
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

// /**
//     Returns the value contained within the optional _or_ another value if there no!T

//     Can also be called at the end of a `dispatch` chain
// */
// T or(T)(Optional!T opt, lazy T orValue) {
//     return opt.empty ? orValue : opt.front;
// }

// /// Ditto
// auto or(OD, T)(OD dispatchedOptional, lazy T orValue)
// if (from!"optional.traits".isOptionalDispatcher!OD
//     && is(T == from!"optional.traits".OptionalDispatcherTarget!OD)) {
//     return some(dispatchedOptional).or(orValue);
// }

// unittest {
//     struct S {
//         int f() { return 3; }
//     }

//     static assert(is(typeof(some(S()).dispatch.some) == Optional!S));
// }

// unittest {
//     class C {
//         int i = 0;
//         C mutate() {
//             this.i++;
//             return this;
//         }
//     }

//     auto a = some(new C());
//     auto b = a.dispatch.mutate.mutate.mutate;

//     // Unwrap original should have mutated the object
//     assert(a.unwrap.i == 3);

//     // some(Dispatcher result) should be original Optional type
//     static assert(is(typeof(b.some) == Optional!C));
//     assert(b.some.unwrap.i == 3);
// }

///
unittest {
    // assert(some(3).or(9) == 3);
    // assert(no!int.or(9) == 9);

    // struct S {
    //     int g() { return 3; }
    // }

    // assert(some(S()).dispatch.g.some.or(9) == 3);
    // assert(no!S.dispatch.g.some.or(9) == 9);

    // class C {
    //     int g() { return 3; }
    // }

    // assert(some(new C()).dispatch.g.or(9) == 3);
    // assert(no!C.dispatch.g.or(9) == 9);
}

unittest {
    import std.meta: AliasSeq;
    import std.conv: to;
    import std.algorithm: map;
    foreach (T; QualifiedAlisesOf!(Optional!int)) {
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
        // assert(a + 10 == some(20));
        // assert(b + 10 == none);
        // assert(a - 5 == some(5));
        // assert(b - 5 == none);
        // assert(a * 20 == some(200));
        // assert(b * 20 == none);
        // assert(a / 2 == some(5));
        // assert(b / 2 == none);
        // assert(10 + a == some(20));
        // assert(10 + b == none);
        // assert(15 - a == some(5));
        // assert(15 - b == none);
        // assert(20 * a == some(200));
        // assert(20 * b == none);
        // assert(50 / a == some(5));
        // assert(50 / b == none);
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

// unittest {
//     auto a = some(3);
//     assert(a + 3 == some(6));
//     auto b = no!int;
//     assert(b + 3 == none);
// }

unittest {
    auto n = no!(int);
    auto nc = no!(const int);
    auto ni = no!(immutable int);
    auto s = some!(int)(3);
    auto sc = some!(const int)(3);
    auto si = some(cast(immutable int)3);

    assert(s != n);
    assert(s != nc);
    assert(s != ni);
    assert(sc != n);
    assert(sc != nc);
    assert(sc != ni);
    assert(si != n);
    assert(si != nc);
    assert(si != ni);

    assert(s == sc);
    assert(s == si);
    assert(sc == si);

    assert(n == nc);
    assert(n == ni);
    assert(nc == ni);

    s = 4;
    n = 4;
    assert(s == n);

    static assert( __traits(compiles, { n = 3; }));
    static assert(!__traits(compiles, { ni = 3; }));
    static assert(!__traits(compiles, { nc = 3; }));
    static assert( __traits(compiles, { s = 3; }));
    static assert(!__traits(compiles, { si = 3; }));
    static assert(!__traits(compiles, { sc = 3; }));
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

// unittest {
//     auto n = no!(int);
//     auto nc = no!(const int);
//     auto ni = no!(immutable int);
//     auto o = some!(int)(3);
//     auto oc = some!(const int)(3);
//     auto oi = some!(immutable int)(3);

//     assert(n.unwrap == null);
//     assert(nc.unwrap == null);
//     assert(ni.unwrap == null);

//     auto uo = o.unwrap;
//     auto uoc = oc.unwrap;
//     auto uoi = oi.unwrap;

//     assert(uo != null);
//     assert(uoc != null);
//     assert(uoi != null);

//     assert(*uo == 3);
//     assert(*uoc == 3);
//     assert(*uoi == 3);

//     *uo = 4;
//     assert(o == some(4));

//     static assert(!__traits(compiles, *uoc = 4));
//     static assert(!__traits(compiles, *uoi = 4));

//     static assert(is(typeof(uoc) == const(int)*));
//     static assert(is(typeof(uoi) == immutable(int)*));

//     assert(o == some(4));
// }

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

// unittest {
//     struct S {
//         int i = 1;
//     }
//     class C {
//         int i = 1;
//     }
//     auto a = some!C(null);
//     auto b = some!(S*)(null);

//     assert(a.unwrap is null);
//     assert(b.unwrap != null);
//     assert(*b.unwrap == null);

//     a = new C();
//     bool aUnwrapped = false;
//     if (auto c = a.unwrap) {
//         aUnwrapped = true;
//         assert(c.i == 1);
//     }
//     assert(aUnwrapped);

//     b = new S();
//     bool bUnwrapped = false;
//     if (auto s = b.unwrap) {
//         bUnwrapped = true;
//         assert((*s).i == 1);
//     }
//     assert(bUnwrapped);

//     auto c = no!int;
//     assert(c.unwrap is null);
//     c = some(3);
//     bool cUnwrapped = false;
//     if (auto p = c.unwrap) {
//         cUnwrapped = true;
//         assert(*p == 3);
//     }
//     assert(cUnwrapped);
// }

// unittest {
//     class C {}
//     auto a = no!C;
//     auto b = some(new C);
//     b = none;
//     Optional!C c = null;
//     auto d = some(new C);
//     d = null;
//     assert(a == none);
//     assert(a.unwrap is null);
//     assert(a.empty);
//     assert(b == none);
//     assert(b.unwrap is null);
//     assert(b.empty);
//     assert(c == none);
//     assert(c.unwrap is null);
//     assert(c.empty);
//     assert(d == none);
//     assert(d.unwrap is null);
//     assert(d.empty);
// }

unittest {
    auto a = some!(immutable int)(1);
    a = 2;
    assert(a == some(2));
}

// unittest {
//     Optional!(immutable int) oii = some!(immutable int)(5);
//     immutable(int)* p = oii.unwrap;
//     assert(*p == 5);
//     oii = 4;
//     assert(*oii.unwrap == 4);
//     assert(*p == 5);
// }
