module optional.dispatch;

import optional.optional: Optional;
import optional.internal;

enum isNullDispatchable(T) = is(T == class) || is(T == interface) || from!"std.traits".isPointer!T;

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

struct NullSafeValueDispatcher(T) {
    import std.traits: hasMember;

    Optional!T value;
    alias value this;

    this(Optional!T value) {
        this.value = value;
    }

    this(T value) {
        this.value = value;
    }

    template opDispatch(string name) if (hasMember!(T, name)) {
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

auto dispatch(T)(auto ref T value) if (isNullDispatchable!T) {
    return NullSafeValueDispatcher!T(value);
}

auto dispatch(T)(auto ref Optional!T value) {
    return NullSafeValueDispatcher!T(value);
}
