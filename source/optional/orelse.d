/**
    Gets the value or else something else
*/
module optional.orelse;

import bolts.from;

/**
    Retrieves the value if it is a valid value else it will retrieve the `elseValue`. Instead of
    an `elseValue`, an `elsePred` can be passed to create the value functionally

    Params:
        value = the value to resolve
        elseValue = the value to get if `value` cannot be resolved
        elsePred = the perdicate to call if `value` cannot be resolved

    Returns:
        $(LI If `value` is testable to null and null, then it will return `elsePred`, else `value`)
        $(LI If `value` is typecons.Nullable and isNull, then it will return `elsePred`, else `value`)
        $(LI If `value` is a range and empty, and `elseValue` is a compatible range,
            then `elseValue` range will be returned, else `value`)
        $(LI If `value` is a range and empty, and `elseValue` is an `ElementType!Range`,
            then `elseValue` will be returned, else `value.front`)
*/
auto ref orElse(alias elsePred, T)(auto ref T value) {

    import std.typecons: Nullable;
    import optional.traits: isOptional, OptionalTarget;

    alias ElseType = typeof(elsePred());

    // The order of these checks matter

    static if (is(T : Nullable!U, U)) {

        // Do this before Range because it could be aliased to a range, in which canse if there's
        // nothing inside, simply calling .empty on it will get Nullables's .get implicitly. BOOM!

        // Does the elsePred return a nullable? That means we are coalescing
        static if (is(ElseType : Nullable!V, V)) {
            if (value.isNull) {
                return elsePred();
            } else {
                return value;
            }
        } else {
            if (value.isNull) {
                return elsePred();
            } else {
                return value.get;
            }
        }

    } else static if (isOptional!T) {

        // Specifically seperate form isInputRange because const optionals are not ranges

        // Does elsePred return another optional? That means we are coalescing
        static if (isOptional!ElseType) {
            if (value.empty) {
                return elsePred();
            } else {
                return value;
            }
        } else {
            if (value.empty) {
                return elsePred();

            } else {
                return value.front;
            }
        }

    } else static if (from.std.range.isInputRange!T) {

        import std.range: ElementType, isInputRange, empty, front;

        static if (is(ElseType : ElementType!T)) {
            if (value.empty) {
                return elsePred();
            } else {
                return value.front;
            }
        } else static if (is(T : ElseType)) {
            // Coalescing to the same range type
            if (value.empty) {
                return elsePred();
            } else {
                return value;
            }
        } else static if (isInputRange!ElseType) {
            // If it's a range but not implicly convertible we can use choose
            import std.range: choose;
            return choose(value.empty, elsePred(), value);
        } else {
            static assert(
                0,
                "elsePred must return either an element or range or another Range"
            );
        }
    } else static if (from.bolts.isNullTestable!T) {
        if (value is null) {
            return elsePred();
        }
        return value;
    } else {
        static assert(0,
            "Unable to call orElse on type " ~ T.stringof ~ ". It has to either be an input range,"
            ~ " a null testable type, a Nullable!T or implement hookOrElse(alias elsePred)()"
        );
    }
}

/// Ditto
auto ref orElse(T, U)(auto ref T value, lazy U elseValue) {
    return value.orElse!(elseValue);
}

///
@("works with ranges, front, and lambdas")
unittest {
    import std.algorithm.comparison: equal;

    // Get orElse ranges
    assert((int[]).init.orElse([1, 2, 3]).equal([1, 2, 3]));
    assert(([789]).orElse([1, 2, 3]).equal([789]));

    // Get orElse front of ranges
    assert((int[]).init.orElse(3) == 3);
    assert(([789]).orElse(3) == 789);

    // Lambdas
    assert(([789]).orElse!(() => 3) == 789);
    assert(([789]).orElse!(() => [1, 2, 3]).equal([789]));
}

