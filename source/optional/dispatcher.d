module optional.dispatcher;

import optional.internal;

private string autoReturn(string expression)() {
    return `
        auto ref expr() {
            return ` ~ expression ~ `;
        }
        ` ~ q{

        import std.traits: Unqual;
        import optional: no, some;

        auto ref val() {
            // If the dispatched result is an Optional itself, we flatten it out so that client code
            // does not have to do a.dispatch.member.front.otherMember - because we'd end up with an
            // Optional!(Optional!ReturnValue).
            static if (isOptional!(typeof(expr()))) {
                return expr().front;
            } else {
                return expr();
            }
        }

        alias R = typeof(val());

        // This is used to check if the expression results in a reference to a value type and is the same type
        enum isRefValueType = is(Unqual!R == Unqual!Target) && (is(Target == struct) || is(Target == union)) && is(typeof(&val()));

        static if (is(R == void)) {
            // no return value, just call
            if (!empty()) {
                val();
            }
        } else static if (isRefValueType) {
            import optional.optionalref;
            if (empty()) {
                return OptionalRef!R(no!R());
            }
            R* ptr = &val();
            if (ptr == &source.front()) { // is instance the same?
                return OptionalRef!R(source);
            } else {
                return OptionalRef!R(some(*ptr));
            }
        } else {
            if (empty()) {
                return no!R;
            } else {
                return some(val());
            }
        }
    };
}

package struct Dispatcher(T) {
    import std.traits: hasMember;
    import optional.traits: isOptional;
    import optional: Optional;

    private alias Target = T;

    private Optional!Target* source;

    @disable this(); // Do not allow user creation of a Dispatcher
    @disable this(this) {} // Do not allow blitting either
    @disable void opAssign(Dispatcher!T); // Do not allow identity assignment

    // Differentiate between pointers to optionals and non pointers. When a dispatch
    // chain is started, the optional that starts it creates a Dispatcher with its address
    // so that we can start a chain if needed.
    private this(U)(auto ref inout(U*) opt) inout if (isOptional!U) {
        source = opt;
    }

    public template opDispatch(string dispatchName) if (hasMember!(Target, dispatchName)) {

        ref Optional!Target get() {
            return *source;
        }

        bool empty() {
            import std.traits: isPointer;
            static if (isPointer!Target)
                return get.empty || get.front is null;
            else
                return get.empty;
        }

        import bolts.traits: hasProperty, isManifestAssignable;
        static if (is(typeof(__traits(getMember, Target, dispatchName)) == function)) {
            // non template function
            auto ref opDispatch(Args...)(auto ref Args args) {
                mixin(autoReturn!("get.front." ~ dispatchName ~ "(args)"));
            }
        } else static if (hasProperty!(Target, dispatchName)) {
            // read and write properties
            import bolts.traits: propertySemantics;
            enum property = propertySemantics!(Target, dispatchName);
            static if (property.canRead) {
                @property auto ref opDispatch()() {
                    mixin(autoReturn!("get.front." ~ dispatchName));
                }
            }
            static if (property.canWrite) {
                @property auto ref opDispatch(V)(auto ref V v) {
                    mixin(autoReturn!("get.front." ~ dispatchName ~ " = v"));
                }
            }
        } else static if (is(typeof(mixin("get.front." ~ dispatchName)))) {
            // non-function field
            auto ref opDispatch(Args...)(auto ref Args args) {
                static if (Args.length == 0) {
                    mixin(autoReturn!("get.front." ~ dispatchName));
                } else static if (Args.length == 1) {
                    mixin(autoReturn!("get.front." ~ dispatchName ~ " = args[0]"));
                } else {
                    static assert(
                        0,
                        "Dispatched " ~ T.stringof ~ "." ~ dispatchName ~ " was resolved to non-function field that has more than one argument",
                    );
                }
            }
        } else {
            // member template
            template opDispatch(Ts...) {
                enum targs = Ts.length ? "!Ts" : "";
                auto ref opDispatch(Args...)(auto ref Args args) {
                    mixin(autoReturn!("get.front." ~ dispatchName ~ targs ~ "(args)"));
                }
            }
        }
    }
}

@("Should not allow construction of Dispatcher")
unittest {
    struct S {
        void f() {}
    }
    static assert(!__traits(compiles, { Dispatcher!S a; }));
    Dispatcher!S b = Dispatcher!S.init;
    static assert(!__traits(compiles, { auto c = b; }));
}
