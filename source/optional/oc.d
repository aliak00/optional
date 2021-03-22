/**
    Provides safe dispatching utilities
*/
module optional.oc;

import optional.optional: Optional;
import std.typecons: Nullable;
import bolts.from;

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
            if (!value.empty) {
                val();
            }
        } else {
            if (value.empty) {
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

package struct OptionalChain(T) {
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

    static if (hasMember!(T, "empty")) {
        public auto empty() {
            if (value.empty) {
                return no!(typeof(T.empty));
            } else {
                return some(value.front.empty);
            }
        }
    } else {
        public auto empty() {
            return value.empty;
        }
    }

    static if (hasMember!(T, "front")) {
        public auto front() {
            if (value.empty) {
                return no!(typeof(T.front));
            } else {
                return some(value.front.front);
            }
        }
    } else {
        public auto front() {
            return value.front;
        }
    }

    static if (hasMember!(T, "popFront")) {
        public auto popFront() {
            if (value.empty) {
                return no!(typeof(T.popFront));
            } else {
                return some(value.front.popFront);
            }
        }
    } else {
        public auto popFront() {
            return value.popFront;
        }
    }

    public template opDispatch(string name) if (hasMember!(T, name)) {
        import optional: no, some;
        static if (is(typeof(__traits(getMember, T, name)) == function)) {
            auto opDispatch(Args...)(auto ref Args args) {
                mixin(autoReturn!("value.front." ~ name ~ "(args)"));
            }
        } else static if (__traits(isTemplate, mixin("T." ~ name))) {
            // member template
            template opDispatch(Ts...) {
                enum targs = Ts.length ? "!Ts" : "";
                auto opDispatch(Args...)(auto ref Args args) {
                    mixin(autoReturn!("value.front." ~ name ~ targs ~ "(args)"));
                }
            }
        } else {
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
    auto c = no!(A*);
    oc(a).inner.g; // calls inner and calls g
    oc(b).inner.g; // no op.
    oc(c).inner.g; // no op.
    ---
*/
auto oc(T)(auto ref T value) if (from.bolts.traits.isNullTestable!T) {
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
