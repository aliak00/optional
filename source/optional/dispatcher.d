module optional.dispatcher;

import optional.internal;

package struct Dispatcher(T) {
    import std.traits: hasMember;
    import optional.traits: isOptional;
    import optional: Optional, None, none;

    private alias Target = T;

    private union Data {
        Optional!T* ptr;
        Optional!T val;
    }

    private Data data = Data.init;
    private bool isVal = false;

    @property ref inout(Optional!T) self() inout {
        return this.isVal ? this.data.val : *this.data.ptr;
    }

    @disable this(); // Do not allow user creation of a Dispatcher
    @disable this(this) {} // Do not allow blitting either
    @disable void opAssign(Dispatcher!T); // Do not allow identity assignment

    // Copy over the opAssigns fomr Optional!T. There are two reasons why the alias this opAssigns do not carry over:
    //  1. Since we define an opAssign, all subtype overloads are hidden so we need to be explicitly redefine them
    //  2. We define a posblit so an identity opAssign is generated (which has the same consequences as us defining one)
    public void opAssign()(const None) { self = none; }
    public void opAssign(U)(auto ref U lhs) { self = lhs; }

    // Differentiate between pointers to optionals and non pointers. When a dispatch
    // chain is started, the optional that starts it creates a Dispatcher with its address
    // so that we can start a chain if needed.
    package this(U)(auto ref inout(U*) opt) inout if (isOptional!U) {
        data.ptr = opt;
        isVal = false;
    }

    private this(U)(auto ref inout(U) opt) inout if (isOptional!U) {
        data.val = opt;
        isVal = true;
    }

    public alias self this;

    static if (!hasMember!(Target, "toString")) {
        /// Converts value to string
        string toString() const {
            return self.toString;
        }
    }
    static if (isOptional!Target) {
        import optional: OptionalTarget, no;
        alias U = OptionalTarget!Target;
        public auto opDispatch(string dispatchName, Args...)(auto ref Args args) {
            if (!self.empty) {
                return Dispatcher!U(self.front).opDispatch!dispatchName(args);
            } else {
                return Dispatcher!U(no!U).opDispatch!dispatchName(args);
            }
        }
    } else {
        public template opDispatch(string dispatchName) if (hasMember!(Target, dispatchName)) {

            bool empty() {
                import std.traits: isPointer;
                static if (isPointer!T)
                    return self.empty || self.front is null;
                else
                    return self.empty;
            }

            static string autoReturn(string expression) {
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
                        // In this case we want to see if the references that is returned from the dispatched expression is the same
                        // as the value that is held in the Optional that we are dispatching on.
                        // We return the same Dispatcher object if that's true.
                        if (empty()) {
                            return Dispatcher!(R)(no!R);
                        }
                        R* ptr = &val();
                        if (ptr == &self.front()) { // is instance the same?
                            import std.algorithm: move;
                            return move(this);
                        } else {
                            return some(*ptr).dispatch;
                        }
                    } else {
                        if (empty()) {
                            return Dispatcher!(R)(no!R);
                        } else {
                            return Dispatcher!(R)(some(val()));
                        }
                    }
                };
            }

            import bolts.traits: hasProperty, isManifestAssignable;
            static if (is(typeof(__traits(getMember, Target, dispatchName)) == function)) {
                // non template function
                auto ref opDispatch(Args...)(auto ref Args args) {
                    mixin(autoReturn("self.front." ~ dispatchName ~ "(args)"));
                }
            } else static if (hasProperty!(Target, dispatchName)) {
                // read and write properties
                import bolts.traits: propertySemantics;
                enum property = propertySemantics!(Target, dispatchName);
                static if (property.canRead) {
                    @property auto ref opDispatch()() {
                        mixin(autoReturn("self.front." ~ dispatchName));
                    }
                }
                static if (property.canWrite) {
                    @property auto ref opDispatch(V)(auto ref V v) {
                        mixin(autoReturn("self.front." ~ dispatchName ~ " = v"));
                    }
                }
            } else static if (is(typeof(mixin("self.front." ~ dispatchName)))) {
                // non-function field
                auto ref opDispatch() {
                    mixin(autoReturn("self.front." ~ dispatchName));
                }
            } else {
                // member template
                template opDispatch(Ts...) {
                    enum targs = Ts.length ? "!Ts" : "";
                    auto ref opDispatch(Args...)(auto ref Args args) {
                        mixin(autoReturn("self.front." ~ dispatchName ~ targs ~ "(args)"));
                    }
                }
            }
        }
    }
}

package template isDispatcher(T) {
    static if (is(T U == Dispatcher!U)) {
        enum isDispatcher = true;
    } else {
        enum isDispatcher = false;
    }
}

@("Should be valid for trait isDispatcher")
unittest {
    import optional: some;
    struct S { int f() { return 3; } }
    static assert(isDispatcher!(typeof(some(S()).dispatch())));
    static assert(isDispatcher!(typeof(some(S()).dispatch.f())));
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
