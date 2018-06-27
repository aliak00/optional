/**
    Optional compile time traits
*/
module optional.traits;

import optional.internal;

/// Checks if T is an optional type
template isOptional(T) {
    import optional: Optional;
    static if (is(T U == Optional!U)) {
        enum isOptional = true;
    } else {
        enum isOptional = false;
    }
}

///
unittest {
    import optional: Optional;

    assert(isOptional!(Optional!int) == true);
    assert(isOptional!int == false);
    assert(isOptional!(int[]) == false);
}

/// Returns the target type of a optional.
template OptionalTarget(T) if (isOptional!T) {
    import std.range: ElementType;
    alias OptionalTarget = ElementType!T;
}

///
unittest {
    import optional: Optional;

    class C {}
    struct S {}

    import std.meta: AliasSeq;
    foreach (T; AliasSeq!(int, int*, S, C, int[], S[], C[])) {
        alias CT = const T;
        alias IT = immutable T;
        alias ST = shared T;

        static assert(is(OptionalTarget!(Optional!T) == T));
        static assert(is(OptionalTarget!(Optional!CT) == CT));
        static assert(is(OptionalTarget!(Optional!IT) == IT));
        static assert(is(OptionalTarget!(Optional!ST) == ST));
    }
}

/**
    Checks if T is a type that was dispatched from an optional

    When you start a `dispatch` chain on an optional type, a proxy type
    used only for dispatching is returned that allows chaining like:

    ---
    struct S1 { int f() { return 3; } }
    struct S2 { S1 f() { return S1(); } }
    auto result = some(S2()).dispatch.f.f; // <-- dispatch chain
    // result is a proxy type
    auto opt = some(result); // this turns it in to an optional
    ---
*/
template isOptionalDispatcher(T) {
    import optional.dispatcher: OptionalDispatcher;

    static if (is(T U == OptionalDispatcher!U))
    {
        enum isOptionalDispatcher = true;
    }
    else
    {
        enum isOptionalDispatcher = false;
    }
}

///
unittest {
    import optional: some;
    struct S { int f() { return 3; } }
    static assert(isOptionalDispatcher!(typeof(some(S()).dispatch())));
    static assert(isOptionalDispatcher!(typeof(some(S()).dispatch.f())));
}

/**
    Gives you the type of a dispatch chain
*/
template OptionalDispatcherTarget(OD) if (isOptionalDispatcher!OD) {
    import optional.dispatcher: OptionalDispatcher;
    static if (is(OD : OptionalDispatcher!P, P...))
    {
        alias OptionalDispatcherTarget = P[0];
    }
    else
        alias OptionalDispatcherTarget = void;
}

unittest {
    import optional: some;
    struct S { int f() { return 3; } }
    static assert(is(OptionalDispatcherTarget!(typeof(some(S()).dispatch())) == S));
    static assert(is(OptionalDispatcherTarget!(typeof(some(S()).dispatch.f())) == int));
}

/// Checks if T is type that is `NotNull`
template isNotNull(T) {
    import optional: NotNull;
    static if (is(T U == NotNull!U)){
        enum isNotNull = true;
    } else {
        enum isNotNull = false;
    }
}

///
unittest {
    import optional: NotNull;

    assert(isNotNull!(NotNull!int) == true);
    assert(isNotNull!int == false);
    assert(isNotNull!(int[]) == false);
}