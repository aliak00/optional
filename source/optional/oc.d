/**
    Provides safe dispatching utilities
*/
module optional.oc;

import optional.optional: Optional;
import std.typecons: Nullable;
import bolts.from;

private enum isNullDispatchable(T) = is(T == class) || is(T == interface) || from.std.traits.isPointer!T;

private string autoReturn(string expression)() {
    return `
        auto ref expr() {
            return ` ~ expression ~ `;
        }
        ` ~ q{
        import optional.traits: isOptional;
        auto ref val() {
            // If the dispatched result is an Optional itself, we flatten it out so that client code
            // does not have to do a.oc.member.oc.otherMember
            static if (isOptional!(typeof(expr()))) {
                return expr().front;
            } else {
                return expr();
            }
        }
        alias R = typeof(val());
        static if (is(R == void)) {
            if (!empty) {
                val();
            }
        } else {
            if (empty) {
                return OptionalChain!R(no!R());
            }
            static if (isOptional!(typeof(expr()))) {
                // If the dispatched result is an optional, check if the expression is empty before
                // calling val() because val() calls .front which would assert if empty.
                if (expr().empty) {
                    return OptionalChain!R(no!R());
                }
            }
            return OptionalChain!R(some(val()));
        }
    };
}

private struct OptionalChain(T) {
    import std.traits: hasMember;

    public Optional!T value;
    alias value this;

    this(Optional!T value) {
        this.value = value;
    }

    this(T value) {
        this.value = value;
    }

    static if (!hasMember!(T, "toString")) {
        public string toString()() {
            return value.toString;
        }
    }

    public template opDispatch(string name) if (hasMember!(T, name)) {
        bool empty() @safe @nogc pure const {
            import std.traits: isPointer;
            static if (isPointer!T) {
                return value.empty || value.front is null;
            } else {
                return value.empty;
            }
        }
        import optional: no, some;
        static if (is(typeof(__traits(getMember, T, name)) == function)) {
            auto opDispatch(Args...)(auto ref Args args) {
                mixin(autoReturn!("value.front." ~ name ~ "(args)"));
            }
        } else static if (is(typeof(mixin("value.front." ~ name)))) {
            // non-function field
            auto opDispatch(Args...)(auto ref Args args) {
                static if (Args.length == 0) {
                    mixin(autoReturn!("value.front." ~ name));
                } else static if (Args.length == 1) {
                    mixin(autoReturn!("value.front." ~ name ~ " = args[0]"));
                } else {
                    static assert(
                        0,
                        "Dispatched " ~ T.stringof ~ "." ~ name ~ " was resolved to non-function field that has more than one argument",
                    );
                }
            }
        } else {
            // member template
            template opDispatch(Ts...) {
                enum targs = Ts.length ? "!Ts" : "";
                auto opDispatch(Args...)(auto ref Args args) {
                    mixin(autoReturn!("value.front." ~ name ~ targs ~ "(args)"));
                }
            }
        }
    }
}

/**
    Allows you to call dot operator on a nullable type or an optional.

    If there is no value inside, or it is null, dispatching will still work but will
    produce a series of no-ops.

    Works with `std.typecons.Nullable`

    If you try and call a manifest constant or static data on T then whether the manifest
    or static immutable data is called depends on if the instance is valid.

    Returns:
        A type aliased to an Optional of whatever T.blah would've returned.
    ---
    struct A {
        struct Inner {
            int g() { return 7; }
        }
        Inner inner() { return Inner(); }
        int f() { return 4; }
    }
    auto a = some(A());
    auto b = no!A;
    auto b = no!(A*);
    a.oc.inner.g; // calls inner and calls g
    b.oc.inner.g; // no op.
    b.oc.inner.g; // no op.
    ---
*/
auto oc(T)(auto ref T value) if (isNullDispatchable!T) {
    return OptionalChain!T(value);
}
/// Ditto
auto oc(T)(auto ref Optional!T value) {
    return OptionalChain!T(value);
}
/// Ditto
auto oc(T)(auto ref Nullable!T value) {
    import optional: no;
    if (value.isNull) {
        return OptionalChain!T(no!T);
    }
    return OptionalChain!T(value.get);
}
