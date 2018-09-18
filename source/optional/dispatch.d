/**
    Provides safe dispatching utilities
*/
module optional.dispatch;

import optional.optional: Optional;
import optional.internal;

private enum isNullDispatchable(T) = is(T == class) || is(T == interface) || from!"std.traits".isPointer!T;

private string autoReturn(string expression)() {
    return `
        auto ref expr() {
            return ` ~ expression ~ `;
        }
        ` ~ q{
        alias R = typeof(expr());
        static if (is(R == void)) {
            if (!empty) {
                expr();
            }
        } else {
            if (empty) {
                return NullSafeValueDispatcher!R(no!R());
            }
            return NullSafeValueDispatcher!R(some(expr()));
        }
    };
}

private struct NullSafeValueDispatcher(T) {
    import std.traits: hasMember;

    public Optional!T value;
    alias value this;

    this(Optional!T value) {
        this.value = value;
    }

    this(T value) {
        this.value = value;
    }

    public template opDispatch(string name) if (hasMember!(T, name)) {
        bool empty() @safe @nogc pure const {
            import std.traits: isPointer;
            static if (isPointer!T) {
                return value.front is null;
            } else {
                return value.empty;
            }
        }
        import optional: no, some, unwrap;
        static if (is(typeof(__traits(getMember, T, name)) == function)) {
            auto ref opDispatch(Args...)(auto ref Args args) {
                mixin(autoReturn!("value.front." ~ name ~ "(args)"));
            }
        } else static if (is(typeof(mixin("value.front." ~ name)))) {
            // non-function field
            auto ref opDispatch(Args...)(auto ref Args args) {
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
                auto ref opDispatch(Args...)(auto ref Args args) {
                    mixin(autoReturn!("value.front." ~ name ~ targs ~ "(args)"));
                }
            }
        }
    }
}

/**
    Allows you to call dot operator on a nullable type of an optional.

    If there is no value inside, or it is null, dispatching will still work but will
    produce a series of no-ops.

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
    a.dispatch.inner.g; // calls inner and calls g
    b.dispatch.inner.g; // no op.
    b.dispatch.inner.g; // no op.
    ---
*/
auto dispatch(T)(auto ref T value) if (isNullDispatchable!T) {
    return NullSafeValueDispatcher!T(value);
}
/// Ditto
auto dispatch(T)(auto ref Optional!T value) {
    return NullSafeValueDispatcher!T(value);
}
