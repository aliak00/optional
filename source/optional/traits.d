/**
    Optional compile time traits
*/
module optional.traits;

import optional.internal;

/// Checks if T is an optional type
template isOptional(T) {
    import optional: Optional;
    import std.traits: isInstanceOf;
    enum isOptional = isInstanceOf!(Optional, T);
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
    import std.traits: TemplateArgsOf;
    alias OptionalTarget = TemplateArgsOf!T[0];
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
    import std.traits: isInstanceOf;
    enum isNotNull = isInstanceOf!(NotNull, T);
}

///
@("Example of isNotNull")
unittest {
    import optional: NotNull;

    class C {}
    assert(isNotNull!(NotNull!C) == true);
    assert(isNotNull!int == false);
    assert(isNotNull!(int[]) == false);
}
