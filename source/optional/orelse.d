/**
    Gets the value or else something else
*/
module optional.orelse;

import bolts.from;

/**
    Retrieves the value if it is a valid value else it will retrieve the `elseValue`. Instead of
    an `elseValue`, an `elsePred` can be passed to create the value functionally.

    This orElse will also act correctly if the `elseValue` is an element of the type being acted on.
    For example if you call orElse on a range, and the `elseValue` is another range, then it will
    return the "other range" if the current range is empty. It will do the same for `std.typecons.Nullable`
    and for `Optional`.

    Params:
        value = the value to resolve
        elseValue = the value to get if `value` cannot be resolved
        elsePred = the perdicate to call if `value` cannot be resolved

    Returns:
        $(LI When `value` is testable to null: if null, it will return `elseValue`, else `value`)
        $(LI When `value` is `std.typecons.Nullable`: if isNull is true, then it will return `elseValue`. If false, and
            `elseValue` is a `Nullable` it will return `value`, else `value.get`)
        $(LI When `value` is an `Optional`: if empty is true, then it will return `elseValue`. If false, and
            `elseValue` is an `Optional` it will return `value`, else `value.front`)
        $(LI When `value` is a range: if empty is true, then it will return `elseValue`. If false, and
            `elseValue` is a compatible range it will return `value`, else `value.front`)
*/
auto orElse(alias elsePred, T)(auto ref T value) {

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
                static if (!is(ElseType == void))
                    return value;
            }
        } else {
            if (value.isNull) {
                return elsePred();
            } else {
                static if (!is(ElseType == void))
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
                static if (!is(ElseType == void))
                    return value;
            }
        } else {
            if (value.empty) {
                return elsePred();
            } else {
                static if (!is(ElseType == void))
                    return value.front;
            }
        }

    } else static if (from.std.range.isInputRange!T) {

        import std.range: ElementType, isInputRange, empty, front;

        static if (is(ElseType : ElementType!T)) {
            if (value.empty) {
                return elsePred();
            } else {
                static if (!is(ElseType == void))
                    return value.front;
            }
        } else static if (is(T : ElseType)) {
            // Coalescing to the same range type
            if (value.empty) {
                return elsePred();
            } else {
                static if (!is(ElseType == void))
                    return value;
            }
        } else static if (isInputRange!ElseType) {
            // If it's a range but not implicly convertible we can use choose
            import std.range: choose;
            static if (!is(ElseType == void)) {
                return choose(value.empty, elsePred(), value);
            } else {
                if (value.empty) {
                    elsePred();
                }
            }
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
        static if (!is(ElseType == void))
            return value;
    } else {
        static assert(0,
            "Unable to call orElse on type " ~ T.stringof ~ ". It has to either be an input range,"
            ~ " a null testable type, a Nullable!T or implement hookOrElse(alias elsePred)()"
        );
    }
}

/// Ditto
auto orElse(T, U)(auto ref T value, lazy U elseValue) {
    return value.orElse!(elseValue);
}

///
@("works with ranges, front, and lambdas")
unittest {
    import optional.optional: some, no;

    auto opt0 = no!int;
    auto opt1 = some(1);

    // Get orElse optional
    assert(opt0.orElse(some(789)) == some(789));
    assert(opt1.orElse(some(789)) == opt1);

    // Get orElse front of optional
    assert(opt0.orElse(789) == 789);
    assert(opt1.orElse(789) == 1);

    // Lambdas
    assert(opt0.orElse!(() => 789) == 789);
    assert(opt0.orElse!(() => some(789)) == some(789));

    // Same with arrays/ranges

    int[] arr0;
    int[] arr1  = [1, 2];

    // Get orElse ranges
    assert(arr0.orElse([789]) == [789]);
    assert(arr1.orElse([789]) == arr1);

    // Get orElse front of range
    assert(arr0.orElse(789) == 789);
    assert(arr1.orElse(789) == 1);

    // Lambdas
    assert(arr0.orElse!(() => 789) == 789);
    assert(arr0.orElse!(() => [789]) == [789]);
}
