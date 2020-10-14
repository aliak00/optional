/**
    Optional compile time traits
*/
module optional.traits;

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

/// Checks if T is an optional chain
template isOptionalChain(T) {
    import optional: OptionalChain;
    import std.traits: isInstanceOf;
    enum isOptionalChain = isInstanceOf!(OptionalChain, T);
}

///
@("Example of isOptionalChain")
@safe @nogc unittest {
    import optional: oc, some;
    static assert(isOptionalChain!(typeof(oc(some(3)))));
}
