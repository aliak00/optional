/**
    Gets the value or else something else
*/
module optional.orelse;

import bolts.from;

/**
    If value is valid, it returns the internal value. This means .front for a range, .get for a Nullable!T, etc.
    If value is invalid, then elseValue is returned. If an elsePred is provided than that is called.

    `elsePred` can return void as well, in which case frontOrElse also returns void.

    Params:
        value = the value to check
        elseValue = the value to get if `value` is invalid
        elsePred = the perdicate to call if `value` is invalid

    Returns:
        $(LI `Nullable!T`: `value.get` or `elseValue`)
        $(LI `Optional!T`: `value.front` or `elseValue`)
        $(LI `Range!T`: `value.front` or `elseValue`)
*/
auto frontOrElse(alias elsePred, T)(auto ref T value) {

    alias ElseType = typeof(elsePred());
    auto ref ret(T)(auto ref T v) {
        static if (!is(ElseType == void))
            return v;
    }

    import std.typecons: Nullable;
    import optional.traits: isOptional;


    // The order of these checks matter

    static if (is(T : Nullable!U, U)) {
        // Do this before Range because it could be aliased to a range, in which canse if there's
        // nothing inside, simply calling .empty on it will get Nullables's .get implicitly. BOOM!
        if (value.isNull) {
            return elsePred();
        } else {
            return ret(value.get);
        }
    } else static if (isOptional!T) {
        // Specifically seperate form isInputRange because const optionals are not ranges
        if (value.empty) {
            return elsePred();
        } else {
            static if (!is(ElseType == void))
                return value.front;
        }
    } else static if (from.std.range.isInputRange!T) {
        import std.range: empty, front;
        if (value.empty) {
            return elsePred();
        } else {
            static if (!is(ElseType == void))
                return value.front;
        }
    } else {
        static assert(0,
            "Unable to call frontOrElse on type " ~ T.stringof ~ ". It has to either be an input range,"
            ~ " a Nullable!T, or an Optional!T"
        );
    }
}

/// Ditto
auto frontOrElse(T, U)(auto ref T value, lazy U elseValue) {
    return value.frontOrElse!(elseValue);
}

///
@("orElse example")
unittest {
    import optional.optional: some, no;

    auto opt0 = no!int;
    auto opt1 = some(1);

    // Get orElse optional
    assert(opt0.frontOrElse(789) == 789);
    assert(opt1.frontOrElse(789) == 1);

    // Lambdas
    assert(opt0.frontOrElse!(() => 789) == 789);
    assert(opt1.frontOrElse!(() => 789) == 1);

    // Same with arrays/ranges

    int[] arr0;
    int[] arr1  = [1, 2];

    // Get frontOrElse optional
    assert(arr0.frontOrElse(789) == 789);
    assert(arr1.frontOrElse(789) == 1);

    // Lambdas
    assert(arr0.frontOrElse!(() => 789) == 789);
    assert(arr1.frontOrElse!(() => 789) == 1);
}

/**
    If value is valid, it returns the value. If value is invalid, then elseValue is returned.
    If an elsePred is provided than that is called.

    `elsePred` can return void as well, in which case frontOrElse also returns void.

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
auto orElse(alias elsePred, T)(auto ref T value) {

    import std.typecons: Nullable;
    import std.range: isInputRange;
    import optional.traits: isOptional, OptionalTarget;

    alias ElseType = typeof(elsePred());

    // The order of these checks matter

    static if (is(T : Nullable!U, U)) {
        // Do this before Range because it could be aliased to a range, in which case if there's
        // nothing inside, simply calling .empty on it will get Nullables's .get implicitly. BOOM!
        if (value.isNull) {
            return elsePred();
        } else {
            static if (!is(ElseType == void))
                return value;
        }
    } else static if (isOptional!T) {
        // Specifically seperate form isInputRange because const optionals are not ranges
        if (value.empty) {
            return elsePred();
        } else {
            static if (!is(ElseType == void))
                return value;
        }
    } else static if (isInputRange!T) {
        import std.range: empty;
        static if (is(ElseType : T)) {
            // Coalescing to the same range type
            if (value.empty) {
                return elsePred();
            } else {
                static if (!is(ElseType == void))
                    return value;
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
    } else static if (from.bolts.isNullTestable!T) {
        if (value is null) {
            return elsePred();
        }
        static if (!is(ElseType == void))
            return value;
    } else {
        static assert(0,
            "Unable to call frontOrElse on type " ~ T.stringof ~ ". It has to either be an input range,"
            ~ " a null testable type, a Nullable!T, or an Optional!T"
        );
    }
}

/// Ditto
auto orElse(T, U)(auto ref T value, lazy U elseValue) {
    return value.orElse!(elseValue);
}

///
@("orElse example")
unittest {
    import optional.optional: some, no;

    auto opt0 = no!int;
    auto opt1 = some(1);

    // Get orElse optional
    assert(opt0.orElse(opt1) == opt1);
    assert(opt1.orElse(opt0) == opt1);

    // Lambdas
    assert(opt0.orElse!(() => opt1) == opt1);
    assert(opt1.orElse!(() => opt0) == opt1);

    // Same with arrays/ranges

    int[] arr0;
    int[] arr1  = [1, 2];

    // Get orElse optional
    assert(arr0.orElse(arr1) == arr1);
    assert(arr1.orElse(arr0) == arr1);

    // Lambdas
    assert(arr0.orElse!(() => arr1) == arr1);
    assert(arr1.orElse!(() => arr0) == arr1);
}
