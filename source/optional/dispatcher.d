module optional.dispatcher;

import optional.internal;

package struct Dispatcher(T) {
    import std.traits: hasMember;
    import optional.traits: isOptional;
    import optional: Optional, None, none;

    private alias Target = T;

    private Optional!Target* source;

    @disable this(); // Do not allow user creation of a Dispatcher
    @disable this(this) {} // Do not allow blitting either
    @disable void opAssign(Dispatcher!T); // Do not allow identity assignment

    // Differentiate between pointers to optionals and non pointers. When a dispatch
    // chain is started, the optional that starts it creates a Dispatcher with its address
    // so that we can start a chain if needed.
    package this(U)(auto ref inout(U*) opt) inout if (isOptional!U) {
        source = opt;
    }

    private @property ref Optional!Target get() {
        return *source;
    }

    public alias get this;

    static if (!hasMember!(Target, "toString")) {
        /// Converts value to string
        string toString() const {
            return source.toString;
        }
    }
    public template opDispatch(string dispatchName) if (hasMember!(Target, dispatchName)) {

        import unit_threaded: writelnUt;

        bool empty() {
            import std.traits: isPointer;
            static if (isPointer!Target)
                return source.empty || source.front is null;
            else
                return source.empty;
        }

        static string autoReturn(string expression)() {

            return "auto ref val() { return " ~ expression ~ ";" ~ "}" ~ q{

                import std.traits: Unqual;
                import optional: no, some;
                alias R = typeof(val());
                // If the expression results in a ref value type and is the same as the target type of the Optional being dispatched
                enum isMaybeSelfRefValueType = is(Unqual!R == Unqual!Target) && (is(Target == struct) || is(Target == union)) && is(typeof(&val()));

                static if (is(R == void)) {
                    // no return value, just call
                    if (!empty()) {
                        val();
                    }
                } else static if (isMaybeSelfRefValueType) {
                    import optional.optionalref;
                    // In this case we want to see if the references that is returned from the dispatched expression is the same
                    // as the value that is held in the Optional that we are dispatching on.
                    // We return the same Dispatcher object if that's true.
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

        import bolts.traits: hasProperty, isManifestAssignable;
        static if (is(typeof(__traits(getMember, Target, dispatchName)) == function)) {
            // non template function
            auto ref opDispatch(Args...)(auto ref Args args) {
                mixin(autoReturn!("source.front." ~ dispatchName ~ "(args)"));
            }
        } else static if (hasProperty!(Target, dispatchName)) {
            // read and write properties
            import bolts.traits: propertySemantics;
            enum property = propertySemantics!(Target, dispatchName);
            static if (property.canRead) {
                @property auto ref opDispatch()() {
                    mixin(autoReturn!("source.front." ~ dispatchName));
                }
            }
            static if (property.canWrite) {
                @property auto ref opDispatch(V)(auto ref V v) {
                    mixin(autoReturn!("source.front." ~ dispatchName ~ " = v"));
                }
            }
        } else static if (is(typeof(mixin("source.front." ~ dispatchName)))) {
            // non-function field
            auto ref opDispatch() {
                mixin(autoReturn!("source.front." ~ dispatchName));
            }
        } else {
            // member template
            template opDispatch(Ts...) {
                enum targs = Ts.length ? "!Ts" : "";
                auto ref opDispatch(Args...)(auto ref Args args) {
                    mixin(autoReturn!("source.front." ~ dispatchName ~ targs ~ "(args)"));
                }
            }
        }
    }
}

version(unittest) { import unit_threaded; }
else              { enum ShouldFail; }

@("Should not allow construction of Dispatcher")
unittest {
    struct S {
        void f() {}
    }
    static assert(!__traits(compiles, { Dispatcher!S a; }));
    Dispatcher!S b = Dispatcher!S.init;
    static assert(!__traits(compiles, { auto c = b; }));
}
