module optional.autodispatcher;

private string autoReturn(string expression)() {
    return `
        auto ref expr() {
            return ` ~ expression ~ `;
        }
        ` ~ q{
        alias R = typeof(expr());
        static if (is(R == void)) {
            expr();
        } else {
            alias U = OptionalTarget!R;
            static if (isOptionalRef!R) {
                return AutoDispatcher!U(expr());
            } else {
                return AutoDispatcher!U(OptionalRef!U(expr()));
            }
        }
    };
}

package struct AutoDispatcher(T) {
    import optional;
    import std.traits: hasMember;
    import optional.optionalref;

    @disable this(); // Do not allow user creation
    @disable this(this); // Do not allow blitting either
    @disable void opAssign(AutoDispatcher!T); // Do not allow identity assignment

    package this(OptionalRef!T oref) {
        this.some = oref;
    }

    OptionalRef!T some;
    alias some this;

    template opDispatch(string name) if (hasMember!(T, name)) {
        static if (__traits(isTemplate, mixin("T." ~ name))) {
            template opDispatch(Ts...) {
                auto ref opDispatch(Args...)(auto ref Args args) {
                    mixin(autoReturn!("some.dispatch." ~ name ~ "!Ts(args)"));
                }
            }
        } else {
            auto opDispatch(Args...)(auto ref Args args)  {
                mixin(autoReturn!("some.dispatch.opDispatch!(name)(args)"));
            }
        }
    }
}

@("Should not be copyable")
unittest {
    import optional: some;
    struct S {
        S other() { return S(); }
    }
    auto a = some(S());
    auto d1 = a.autoDispatch;
    auto d2 = a.autoDispatch;
    static assert(!__traits(compiles, { d1 = d2; } ));
    static assert(!__traits(compiles, { d1 = AutoDispatcher!S.init; } ));
    static assert(!__traits(compiles, { d1 = S(); } ));
    static assert(!__traits(compiles, { d1 = none; } ));
}

@("Should not be constructable")
unittest {
    static assert(!__traits(compiles, {
        AutoDispatcher!int d;
    }));
}
