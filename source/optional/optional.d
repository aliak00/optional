/**
    Optional type
*/
module optional.optional;

import std.typecons: Nullable;

import optional.internal;

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

    This can either contain a value or be `none`. It works with any value, including
    values that can be null. I.e. null is a valid value that can be contained inside
    an optional if T is a pointer type

    It also has range like behavior. So this acts as a range that contains 1 element or
    is empty. Similar to `std.algorithm.only`

    And all operations that can be performed on a T can also be performed on an Optional!T.
    The behavior of applying an operation on a no-value or null pointer is well defined
    and safe.
*/

struct Optional(T) {
    import std.traits: isMutable, isSomeFunction, isAssignable, Unqual;

    private enum isNullInvalid = is(T == class) || is(T == interface) || isSomeFunction!T;
    private enum isNullable = is(typeof(T.init is null));

    private T _value = T.init; // Set to init for when T has @disable this()
    private bool defined = false;

    private enum nonEmpty = q{
        static if (isNullInvalid) {
            this.defined = this._value !is null;
        } else {
            this.defined = true;
        }
    };
    private void setNonEmptyState() {
        mixin(nonEmpty);
    }

    /**
        Allows you to create an Optional type in place.

        This is useful if type T has a @disable this(this) for e.g.
    */
    static Optional!T construct(Args...)(auto ref Args args) {
        import std.algorithm: move;
        auto value = T(args);
        Optional!T opt;
        opt._value = move(value);
        opt.setNonEmptyState;
        return move(opt);
    }

    /**
        Constructs an Optional!T value by assigning T

        If T is of class type, interface type, or some function pointer then passing in null
        sets the optional to `none` interally
    */
    this(U : T, this This)(auto ref U value) {
        this._value = value;
        mixin(nonEmpty);
    }
    /// Ditto
    this(const None) {
        // For Error: field _value must be initialized in constructor, because it is nested struct
        this._value = T.init;
    }

    @property bool empty() const {
        static if (isNullInvalid) {
            return !this.defined || this._value is null;
        } else {
            return !this.defined;
        }
    }
    @property ref inout(T) front() inout {
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
    bool opEquals(const None) const { return this.empty; }
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
    bool opEquals(R)(auto ref R other) const if (from!"std.range".isInputRange!R) {
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
    void opAssign()(const None) if (isMutable!T) {
        if (!this.empty) {
            static if (isNullInvalid) {
                this._value = null;
            } else {
                destroy(this._value);
            }
            this.defined = false;
        }
    }
    /// Ditto
    void opAssign(U : T)(auto ref U lhs) if (isMutable!T && isAssignable!(T, U)) {
        this._value = lhs;
        mixin(nonEmpty);
    }
    /// Ditto
    void opAssign(U : T)(auto ref Optional!U lhs) if (isMutable!T && isAssignable!(T, U))  {
        this._value = lhs._value;
        this.defined = lhs.defined;
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
    auto ref opUnary(string op, this This)() {
        import std.traits: isPointer;
        static if (op == "*" && isPointer!T) {
            import std.traits: PointerTarget;
            alias P = PointerTarget!T;
            return empty || front is null ? no!P : some(*this.front);
        } else {
            alias R = typeof(mixin(op ~ "_value"));
            static if (is(R == void)) {
                if (!empty) mixin(op ~ "_value");
            } else {
                alias NoType = typeof(some(mixin(op ~ "_value")));
                if (!empty) {
                    return some(mixin(op ~ "_value"));
                } else {
                    return NoType();
                }
            }
        }
    }

    /**
        If the optional is some value it returns an optional of some `value op rhs`
    */
    auto ref opBinary(string op, U : T, this This)(auto ref U rhs) {
        mixin(autoReturn!("front" ~ op ~ "rhs"));
    }
    /**
        If the optional is some value it returns an optional of some `lhs op value`
    */
    auto ref opBinaryRight(string op, U : T, this This)(auto ref U lhs) {
        mixin(autoReturn!("lhs"  ~ op ~ "front"));
    }

    /**
        If there's a value that's callable it will be called else it's a noop

        Returns:
            Optional value of whatever `T(args)` returns
    */
    auto ref opCall(Args...)(Args args) if (from!"std.traits".isCallable!T) {
        mixin(autoReturn!("this._value(args)"));
    }

    /**
        If the optional is some value, op assigns rhs to it
    */
    auto ref opOpAssign(string op, U : T, this This)(auto ref U rhs) {
        mixin(autoReturn!("front" ~ op ~ "= rhs"));
    }

    static if (from!"std.traits".isArray!T) {
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
        auto ref opIndex(this This)() {
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
    string toString()() const {
        import std.conv: to; import std.traits;
        if (empty) {
            return "[]";
        }
        // Cast to unqual if we can copy so writing it out does the right thing.
        static if (isCopyable!T && __traits(compiles, cast(Unqual!T)this._value)) {
          immutable str = to!string(cast(Unqual!T)this._value);
        } else {
          immutable str = to!string(this._value);
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
                return no!T;
            }
            return some(deserializeJson!T(value));
        }
    }
}

/**
    Type constructor for an optional having some value of `T`

    Calling some on the result of a dispatch chain will result
    in the original optional value.
*/
public auto ref some(T)(auto ref T value) {
    return Optional!T(value);
}

///
@("Example of some()")
@nogc @safe unittest {
    import std.range: only;
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
    assert(a != none);
}

/**
    Get pointer to value. If T is a reference type then T is returned

    Use this to safely access reference types, or to get at the raw value
    of non reference types via a non-null pointer.

    It is recommended that you access internal values by using `orElse` instead though

    Returns:
        Pointer to value or null if empty. If T is reference type, returns reference
*/
public auto ref unwrap(T)(inout auto ref Optional!T opt) {
    static if (is(T == class) || is(T == interface)) {
        return opt.empty ? null : opt.front;
    } else {
        return opt.empty ? null : &opt.front();
    }
}

///
@("Example of unwrap()")
unittest {
    class C {
        int i = 3;
    }

    auto n = no!C;
    if (auto u = n.unwrap) {} else n = some!C(null);
    assert(n == none);
    if (auto u = n.unwrap) {} else n = new C();
    assert(n.unwrap !is null);
    assert(n.unwrap.i == 3);
}

/**
    Returns the value contained within the optional _or else_ another value if there's `no!T`

    Params:
        opt = the optional to call orElse on
        value = The value to return if the optional is empty
        pred = The predicate to call if the optional is empty
*/
public auto ref U orElse(T, U)(inout auto ref Optional!T opt, lazy U value) if (is(U : T)) {
    return opt.orElse!value;
}

/// Ditto
public auto ref orElse(alias pred, T)(inout auto ref Optional!T opt) if (is(typeof(pred()) : T)) {
    return opt.empty ? pred() : opt.front;
}

///
@("Example of orElse()")
unittest {
    assert(some(3).orElse(9) == 3);
    assert(no!int.orElse(9) == 9);
    assert(no!int.orElse!(() => 10) == 10);
}

/**
    Calls an appropriate handler depending on if the optional has a value or not

    Params:
        opt = The optional to call match on
        handlers = 2 predicates, one that takes the underlying optional type and another that names nothing
*/
public template match(handlers...) if (handlers.length == 2) {
	auto ref match(T)(inout auto ref Optional!T opt) {

        static if (is(typeof(handlers[0](opt.front)))) {
            alias someHandler = handlers[0];
            alias noHandler = handlers[1];
        } else {
            alias someHandler = handlers[1];
            alias noHandler = handlers[0];
        }

        import bolts: isFunctionOver;

        static assert(
            isFunctionOver!(someHandler, T) && isFunctionOver!(noHandler),
            "One handler must have one parameter of type '" ~ T.stringof ~ "' and the other no parameter"
        );

        alias RS = typeof(someHandler(opt.front));
        alias RN = typeof(noHandler());

        static assert(
            is(RS == RN),
            "Expected two handlers to return same type, found type '" ~ RS.stringof ~ "' and type '" ~ RN.stringof ~ "'",
        );

        if (opt.empty) {
            return noHandler();
        } else {
            return someHandler(opt.front);
        }
	}
}

///
@("Example of match()")
@nogc @safe unittest {
    auto a = some(3);
    auto b = no!int;

    auto ra = a.match!(
        (int a) => "yes",
        () => "no",
    );

    auto rb = b.match!(
        (a) => "yes",
        () => "no",
    );

    assert(ra == "yes");
    assert(rb == "no");
}

/**
    Converts a range or Nullable to an optional type

    Params:
        range = the range to convert. It must have no more than 1 element
        nullable = the Nullable to convert

    Returns:
        an optional of the element of range or Nullable
*/
auto toOptional(R)(auto ref R range) if (from!"std.range".isInputRange!R) {
    import std.range: walkLength, ElementType, front;
    assert(range.empty || range.walkLength == 1);
    if (range.empty) {
        return no!(ElementType!R);
    } else {
        return some(range.front);
    }
}

/// Ditto
auto toOptional(T)(auto ref Nullable!T nullable) {
    if (nullable.isNull) {
        return no!T;
    } else {
        return some(nullable.get);
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
