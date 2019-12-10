/**
    Optional type
*/
module optional.optional;

import std.typecons: Nullable;
import bolts.from;

package struct None {}

/**
    Represents an empty optional value. This is used to set `Optional`s to have no value
    or for comparisons

    SeeAlso:
        - `Optional.opEquals`
*/
immutable none = None();

private static string autoReturn(string expression)() {
    return `
        auto ref expr() {
            return ` ~ expression ~ `;
        }
        ` ~ q{
        alias R = typeof(expr());
        static if (!is(R == void))
            return empty ? no!R : some!R(expr());
        else {
            if (!empty) {
                expr();
            }
        }
    };
}

/**
    Optional type. Also known as a Maybe or Option type in some languages.

    This can either contain a value or be `none`. If the value is a refernce type then
    `null` is considered `none`.

    It also has range like behavior. So this acts as a range that contains 1 element or
    is empty.

    And all operations that can be performed on a T can also be performed on an Optional!T.
    The behavior of applying an operation on a no-value or null pointer is well defined
    and safe.
*/

struct Optional(T) {
    import std.traits: isMutable, isSomeFunction, isAssignable, isPointer, isArray;

    private enum isNullInvalid = is(T == class) || is(T == interface) || isSomeFunction!T || isPointer!T;

    private T _value = T.init; // Set to init for when T has @disable this()
    private bool defined = false;

    private enum setDefinedTrue = q{
        static if (isNullInvalid) {
            this.defined = this._value !is null;
        } else {
            this.defined = true;
        }
    };

    /**
        Constructs an Optional!T value by assigning T

        If T is of class type, interface type, or some function pointer then passing in null
        sets the optional to `none` interally
    */
    this(T value) pure {
        import std.traits: isCopyable;
        static if (!isCopyable!T) {
            import std.functional: forward;
            this._value = forward!value;
        } else {
            this._value = value;
        }
        mixin(setDefinedTrue);
    }
    /// Ditto
    this(const None) pure {
        // For Error: field _value must be initialized in constructor, because it is nested struct
        this._value = T.init;
    }

    @property bool empty() const nothrow @safe {
        static if (isNullInvalid) {
            return !this.defined || this._value is null;
        } else {
            return !this.defined;
        }
    }
    @property ref inout(T) front() inout return @safe nothrow {
        assert(!empty, "Attempting to fetch the front of an empty optional.");
        return this._value;
    }
    void popFront() { this.defined = false; }

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
    bool opEquals(const None) const @safe nothrow { return this.empty; }
    /// Ditto
    bool opEquals(U : T)(const auto ref Optional!U rhs) const {
        if (this.empty || rhs.empty) return this.empty == rhs.empty;
        return this._value == rhs._value;
    }
    /// Ditto
    bool opEquals(U : T)(const auto ref U rhs) const {
        return !this.empty && this._value == rhs;
    }
    /// Ditto
    bool opEquals(R)(auto ref R other) const if (from.std.range.isInputRange!R) {
        import std.range: empty, front;

        if (this.empty && other.empty) return true;
        if (this.empty || other.empty) return false;
        return this.front == other.front;
    }

    /**
        Assigns a value to the optional or sets it to `none`.

        If T is of class type, interface type, or some function pointer than passing in null
        sets the optional to `none` internally
    */
    auto ref opAssign()(const None) if (isMutable!T) {
        if (!this.empty) {
            static if (isNullInvalid) {
                this._value = null;
            } else {
                destroy(this._value);
            }
            this.defined = false;
        }
        return this;
    }
    /// Ditto
    auto ref opAssign(U : T)(auto ref U lhs) if (isMutable!T && isAssignable!(T, U)) {
        this._value = lhs;
        mixin(setDefinedTrue);
        return this;
    }
    /// Ditto
    auto ref opAssign(U : T)(auto ref Optional!U lhs) if (isMutable!T && isAssignable!(T, U)) {
        static if (__traits(isRef, lhs) || !isMutable!U) {
            this._value = lhs._value;
        } else {
            import std.algorithm: move;
            this._value = move(lhs._value);
        }

        this.defined = lhs.defined;
        return this;
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
    auto opUnary(string op, this This)() {
        mixin(autoReturn!(op ~ "front"));
    }

    /**
        If the optional is some value it returns an optional of some `value op rhs`
    */
    auto opBinary(string op, U : T, this This)(auto ref U rhs) {
        mixin(autoReturn!("front" ~ op ~ "rhs"));
    }
    /**
        If the optional is some value it returns an optional of some `lhs op value`
    */
    auto opBinaryRight(string op, U : T, this This)(auto ref U lhs) {
        mixin(autoReturn!("lhs"  ~ op ~ "front"));
    }

    /**
        If there's a value that's callable it will be called else it's a noop

        Returns:
            Optional value of whatever `T(args)` returns
    */
    auto opCall(Args...)(Args args) if (from.std.traits.isCallable!T) {
        mixin(autoReturn!("this._value(args)"));
    }

    /**
        If the optional is some value, op assigns rhs to it
    */
    auto opOpAssign(string op, U : T, this This)(auto ref U rhs) {
        mixin(autoReturn!("front" ~ op ~ "= rhs"));
    }

    static if (isArray!T) {
        /**
            Provides indexing into arrays

            The indexes and slices are also checked to be valid and `none` is returned if they are
            not
        */
        auto opIndex(this This)(size_t index) {
            enum call = "front[index]";
            import std.range: ElementType;
            if (empty || index >= front.length || index < 0) {
                return no!(mixin("typeof("~call~")"));
            }
            mixin(autoReturn!(call));
        }
        /// Ditto
        auto opIndex(this This)() {
            mixin(autoReturn!("front[]"));
        }
        /// Ditto
        auto opSlice(this This)(size_t begin, size_t end) {
            enum call = "front[begin .. end]";
            import std.range: ElementType;
            if (empty || begin > end || end > front.length) {
                return no!(mixin("typeof("~call~")"));
            }
            mixin(autoReturn!(call));
        }
        /// Ditto
        auto opDollar() const {
            return empty ? 0 : front.length;
        }
    }

    /// Converts value to string
    string toString()() inout {
        if (empty) {
            return "[]";
        }
        static if (__traits(compiles, { this._value.toString; } )) {
            auto str = this._value.toString;
        } else {
            import std.conv: to;
            auto str = to!string(this._value);
        }
        return "[" ~ str ~ "]";
    }

    static if (__traits(compiles, {
        import vibe.data.serialization;
        import vibe.data.json;
        auto a = T.init.serializeToJson;
        auto b = deserializeJson!T(a);
    })) {
        import vibe.data.json;
        Json toRepresentation() const {
            if (empty) {
                return Json.undefined;
            }
            return _value.serializeToJson;
        }
	    static Optional!T fromRepresentation(Json value) {
            if (value == Json.undefined) {
                return Optional!T();
            }
            return Optional!T(deserializeJson!T(value));
        }
    }
}

/**
    Type constructor for an optional having some value of `T`
*/
public auto some(T)(auto ref T value) {
    import std.traits: isMutable, isCopyable;
    static if (!isCopyable!T) {
        import std.functional: forward;
        return Optional!T(forward!value);
    } else {
        return Optional!T(value);
    }
}

///
@("Example of some()")
@nogc @safe unittest {
    import std.range: only;
    import std.algorithm: equal;

    auto a = no!int;
    assert(a == none);
    a = 9;
    assert(a == some(9));
    assert(a != none);

    import std.algorithm: map;
    assert(only(1, 2, 3).map!some.equal(only(some(1), some(2), some(3))));
}

/// Type constructor for an optional having no value of `T`
public auto no(T)() {
    return Optional!T();
}

///
@("Example of no()")
@safe unittest {
    auto a = no!(int*);
    assert(a == none);
    assert(*a != 9);
    a = new int(9);
    assert(*a == 9);
    assert(a != none);
    a = null;
    assert(a == none);
}

/**
    Converts a range or Nullable to an optional type

    Params:
        range = the range to convert. It must have no more than 1 element
        nullable = the Nullable to convert

    Returns:
        an optional of the element of range or Nullable
*/
auto toOptional(R)(auto ref R range) if (from.std.range.isInputRange!R) {
    import std.range: walkLength, ElementType, front;
    assert(range.empty || range.walkLength == 1);
    if (range.empty) {
        return no!(ElementType!R);
    } else {
        return some(range.front);
    }
}

/// Ditto
auto toOptional(T)(auto inout ref Nullable!T nullable) {
    if (nullable.isNull) {
        return inout Optional!T();
    } else {
        return inout Optional!T(nullable.get);
    }
}

///
@("Example of toOptional")
unittest {
    import std.algorithm: map;
    import optional;

    assert(no!int.map!"a".toOptional == none);
    assert(some(1).map!"a".toOptional == some(1));
}

/**
    Turns an Optional in to a Nullable

    Params:
        opt = the optional to convert from a Nullable!T

    Returns:
        An Nullable!T
*/
auto toNullable(T)(auto ref Optional!T opt) {
    import std.typecons: nullable;
    if (opt.empty) {
        return Nullable!T();
    } else {
        return opt.front.nullable;
    }
}

///
@("Example of toNullable")
unittest {
    assert(some(3).toNullable == Nullable!int(3));
    assert(no!int.toNullable == Nullable!int());
}
