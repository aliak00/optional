/**
    Optional compile time traits
*/
module optional.traits;

import optional.internal;

/// Checks if T is an optional type
template isOptional(T) {
    static if (is(T U == Optional!U))
    {
        enum isOptional = true;
    }
    else
    {
        enum isOptional = false;
    }
}

///
unittest {
    assert(isOptional!(Optional!int) == true);
    assert(isOptional!int == false);
    assert(isOptional!(int[]) == false);
}

/// Returns the target type of a optional.
alias OptionalTarget(T : Optional!T) = T;

///
unittest {
    static assert(is(OptionalTarget!(Optional!int) == int));
    static assert(is(OptionalTarget!(Optional!(float*)) == float*));
}
