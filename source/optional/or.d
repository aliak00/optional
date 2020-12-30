/**
    Gets the value or else something else
*/
module optional.or;

import bolts.traits: isNullTestable;
import std.typecons: Nullable;
import std.range: isInputRange;
import optional.traits: isOptional, isOptionalChain;

private enum isTypeconsNullable(T) = is(T : Nullable!U, U);
private auto ret(ElseType, T)(auto ref T v) {
    static if (!is(ElseType == void))
        return v;
}

/**
    If value is valid, it returns the internal value. This means .front for a range, .get for a Nullable!T, etc.
    If value is invalid, then elseValue is returned. If an elsePred is provided than that is called.

    `elsePred` can return void as well, in which case frontOr also returns void.

    Params:
        value = the value to check
        elseValue = the value to get if `value` is invalid
        elsePred = the perdicate to call if `value` is invalid

    Returns:
        $(LI `Nullable!T`: `value.get` or `elseValue`)
        $(LI `Optional!T`: `value.front` or `elseValue`)
        $(LI `Range!T`: `value.front` or `elseValue`)
*/
auto frontOr(alias elsePred, T)(auto ref T value) {

    alias ElseType = typeof(elsePred());

    // The order of these checks matter

    static if (isTypeconsNullable!T) {
        // Do this before Range because it could be aliased to a range, in which canse if there's
        // nothing inside, simply calling .empty on it will get Nullables's .get implicitly. BOOM!
        if (value.isNull) {
            static if (isTypeconsNullable!ElseType) {
                return elsePred().get;
            } else {
                return elsePred();
            }
        } else {
            return ret!ElseType(value.get);
        }
    } else static if (isOptional!T) {
        // Specifically seperate form isInputRange because const optionals are not ranges
        if (value.empty) {
            return elsePred();
        } else {
            return ret!ElseType(value.front);
        }
    } else static if (isInputRange!T) {
        import std.range: empty, front;
        if (value.empty) {
            return elsePred();
        } else {
            return ret!ElseType(value.front);
        }
    } else {
        static assert(0,
            "Unable to call frontOr on type " ~ T.stringof ~ ". It has to either be an input range,"
            ~ " a Nullable!T, or an Optional!T"
        );
    }
}

/// Ditto
auto frontOr(T, U)(auto ref T value, lazy U elseValue) {
    return value.frontOr!(elseValue);
}

///
@("frontOr example")
@safe unittest {
    import optional.optional: some, no;

    auto opt0 = no!int;
    auto opt1 = some(1);

    // Get or optional
    assert(opt0.frontOr(789) == 789);
    assert(opt1.frontOr(789) == 1);

    // Lambdas
    () @nogc {
        assert(opt0.frontOr!(() => 789) == 789);
        assert(opt1.frontOr!(() => 789) == 1);
    }();

    // Same with arrays/ranges

    int[] arr0;
    int[] arr1  = [1, 2];

    // Get frontOr optional
    assert(arr0.frontOr(789) == 789);
    assert(arr1.frontOr(789) == 1);

    // Lambdas
    () @nogc {
        assert(arr0.frontOr!(() => 789) == 789);
        assert(arr1.frontOr!(() => 789) == 1);
    }();
}

/**
    If value is valid, it returns the value. If value is invalid, then elseValue is returned.
    If an elsePred is provided than that is called.

    `elsePred` can return void as well, in which case frontOr also returns void.

    Params:
        value = the value to check
        elseValue = the value to get if `value` is invalid
        elsePred = the perdicate to call if `value` is invalid

    Returns:
        $(LI `Nullable!T`: `value.isNull ? elseValue : value`)
        $(LI `Optional!T`: `value.empty ? elseValue : value`)
        $(LI `Range!T`: `value.empty ? elseValue : value`)
        $(LI `Null-testable type`: `value is null ? elseValue : value`)
*/
auto or(alias elsePred, T)(auto ref T value) {

    alias ElseType = typeof(elsePred());

    // The order of these checks matter

    static if (isTypeconsNullable!T) {
        // Do this before Range because it could be aliased to a range, in which case if there's
        // nothing inside, simply calling .empty on it will get Nullables's .get implicitly. BOOM!
        if (value.isNull) {
            static if (isTypeconsNullable!ElseType) {
                return elsePred().get;
            } else {
                return elsePred();
            }
        } else {
            return ret!ElseType(value.get);
        }
    } else static if (isOptional!T) {
        // Specifically seperate form isInputRange because const optionals are not ranges
        if (value.empty) {
            return elsePred();
        } else {
            return ret!ElseType(value);
        }
    } else static if (isInputRange!T) {
        import std.range: empty;
        static if (is(ElseType : T)) {
            // Coalescing to the same range type
            if (value.empty) {
                return elsePred();
            } else {
                return ret!ElseType(value);
            }
        } else {
            // If it's a range but not implicly convertible we can use choose
            static if (!is(ElseType == void)) {
                import std.range: choose;
                return choose(value.empty, elsePred(), value);
            } else {
                if (value.empty) {
                    elsePred();
                }
            }
        }
    } else static if (isNullTestable!T) {
        if (value is null) {
            return elsePred();
        }
        return ret!ElseType(value);
    } else {
        static assert(0,
            "Unable to call or on type " ~ T.stringof ~ ". It has to either be an input range,"
            ~ " a null testable type, a Nullable!T, or an Optional!T"
        );
    }
}

/// Ditto
auto or(T, U)(auto ref T value, lazy U elseValue) {
    return value.or!(elseValue);
}

///
@("or example")
@safe unittest {
    import optional.optional: some, no;

    auto opt0 = no!int;
    auto opt1 = some(1);

    // Get or optional
    assert(opt0.or(opt1) == opt1);
    assert(opt1.or(opt0) == opt1);

    // Lambdas
    () @nogc {
        assert(opt0.or!(() => opt1) == opt1);
        assert(opt1.or!(() => opt0) == opt1);
    }();

    // Same with arrays/ranges

    int[] arr0;
    int[] arr1  = [1, 2];

    // Get or optional
    assert(arr0.or(arr1) == arr1);
    assert(arr1.or(arr0) == arr1);

    // Lambdas
    () @nogc {
        assert(arr0.or!(() => arr1) == arr1);
        assert(arr1.or!(() => arr0) == arr1);
    }();
}

/**
    An exception that's throw by `frontOrThrow` should the exception maker throw
*/
public class FrontOrThrowException : Exception {
    /// Original cause of this exception
    Exception cause;

    package(optional) this(Exception cause) @safe nothrow pure {
        super(cause.msg);
        this.cause = cause;
    }
}

/**
    Same as `frontOr` except it throws an error if it can't get the value

    Params:
        value = the value to resolve
        makeThrowable = the predicate that creates exception `value` cannot be resolved
        throwable = the value to throw if value cannot be resolved

    Returns:
        $(LI `Nullable!T`: `value.get` or throw)
        $(LI `Optional!T`: `value.front` or throw)
        $(LI `Range!T`: `value.front` or throw)
*/
auto frontOrThrow(alias makeThrowable, T)(auto ref T value) {
    // The orer of these checks matter

    static if (isTypeconsNullable!T) {
        // Do this before Range because it could be aliased to a range, in which canse if there's
        // nothing inside, simply calling .empty on it will get Nullables's .get implicitly. BOOM!
        if (!value.isNull) {
            return value.get;
        }
    } else static if (isOptional!T) {
        if (!value.empty) {
            return value.front;
        }
    } else static if (isInputRange!T) {
        import std.range: empty, front;
        if (!value.empty) {
            return value.front;
        }
    } else {
        static assert(0,
            "Unable to call frontOrThrow on type " ~ T.stringof ~ ". It has to either be an input range,"
            ~ " a Nullable!T, or an Optional!T"
        );
    }

    // None of the static branches returned a value, throw!
    throw () {
        try {
            return makeThrowable();
        } catch (Exception ex) {
            throw new FrontOrThrowException(ex);
        }
    }();
}

/// Ditto
auto frontOrThrow(T, U : Throwable)(auto ref T value, lazy U throwable) {
    return value.frontOrThrow!(throwable);
}

///
@("frontOrThrow example")
@safe unittest {
    import std.exception: assertThrown, assertNotThrown;

    ""
        .frontOrThrow(new Exception(""))
        .assertThrown!Exception;

    auto b = "yo"
        .frontOrThrow(new Exception(""))
        .assertNotThrown!Exception;

    assert(b == 'y');
}
