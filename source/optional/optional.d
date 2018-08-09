/**
    Optional type
*/
module optional.optional;

import optional.internal;

package struct None {}

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

    // auto ref opIndexAssign(U : T, Args...(auto ref U value, auto ref Args...);

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
    // auto dispatch() inout {
    //     import optional.dispatcher: Dispatcher;
    //     return inout Dispatcher!(T)(&this);
    // }
}

/**
    Type constructor for an optional having some value of `T`

    Calling some on the result of a dispatch chain will result
    in the original optional value.
*/
auto ref some(T)(auto ref T value) {
    // import optional.dispatcher: isDispatcher;
    // static if (isDispatcher!T) {
    //     return value.self;
    // } else {
        return Optional!T(value);
    // }
}

///
@("Example of some()")
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
auto no(T)() {
    return Optional!T();
}

///
@("Example of no()")
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

///
@("Example of unwrap()")
unittest {
    class C {
        int i = 3;
    }

    auto n = no!C;
    if (auto u = n.unwrap) {} else n = some!C(null);
    assert(n == none);
    if (auto u = n.unwrap) {} else n = new C();
    assert(n.unwrap !is null);
    assert(n.unwrap.i == 3);
}

/**
    Returns the value contained within the optional _or else_ another value if there's `no!T`

    Can also be called at the end of a `dispatch` chain
*/
T orElse(T)(Optional!T opt, auto ref T value) {
    return opt.empty ? value : opt.front;
}

/// Ditto
// T orElse(T)(Dispatcher!T dispatchedOptional, auto ref T value) {
//     return some(dispatchedOptional).orElse(value);
// }

///
@("Example of orElse()")
unittest {
    assert(some(3).orElse(9) == 3);
    assert(no!int.orElse(9) == 9);

    // struct S {
    //     int g() { return 3; }
    // }

    // assert(some(S()).dispatch.g.some.orElse(9) == 3);
    // assert(no!S.dispatch.g.some.orElse(9) == 9);

    // class C {
    //     int g() { return 3; }
    // }

    // assert(some(new C()).dispatch.g.orElse(9) == 3);
    // assert(no!C.dispatch.g.orElse(9) == 9);
}

deprecated("This will go away, use 'orElse' instead")
T or(T)(Optional!T opt, auto ref T value) {
    return opt.empty ? value : opt.front;
}

deprecated("This will go away, use 'orElse' instead")
T or(T)(Dispatcher!T dispatchedOptional, auto ref T value) {
    return some(dispatchedOptional).orElse(value);
}
