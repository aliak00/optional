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
@("Example of isOptional")
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
@("Example of OptionalTarget")
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
@("Example of isNotNull")
unittest {
    import optional: NotNull;

    assert(isNotNull!(NotNull!int) == true);
    assert(isNotNull!int == false);
    assert(isNotNull!(int[]) == false);
}
