module optional.dispatcher;

import optional.internal;

struct Dispatcher(T) {
    import std.traits: hasMember;
    import optional.traits: isOptional;
    import optional: Optional;

    private alias Target = T;

    private union Data {
        Optional!T* ptr;
        Optional!T val;
    }

    private Data data = Data.init;
    private bool isVal = false;

    package @property ref Optional!T self() {
        return isVal ? data.val : *data.ptr;
    }

    @disable this(); // Do not allow user creation of a Dispatcher
    @disable this(this) {} // Do not allow blitting either

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

    alias self this;

    template opDispatch(string dispatchName) if (hasMember!(Target, dispatchName)) {

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

version (unittest) {
    import optional: no, some, unwrap;
}

unittest {
    struct A {
        enum aManifestConstant = "aManifestConstant";
        static immutable aStaticImmutable = "aStaticImmutable";
        auto aField = "aField";
        auto aNonTemplateFunctionArity0() {
            return "aNonTemplateFunctionArity0";
        }
        auto aNonTemplateFunctionArity1(string value) {
            return "aNonTemplateFunctionArity1";
        }
        @property string aProperty() {
            return aField;
        }
        @property void aProperty(string value) {
            aField = value;
        }
        string aTemplateFunctionArity0()() {
            return "aTemplateFunctionArity0";
        }
        string aTemplateFunctionArity1(string T)() {
            return "aTemplateFunctionArity1";
        }
        string dispatch() {
            return "dispatch";
        }

        // static int * p = new int;
        // static immutable int * nullPointer = null;
        // static immutable int * nonNullPointer = new int(3);
    }

    import bolts.traits: isManifestAssignable;

    auto a = some(A());
    auto b = no!A;
    assert(a.dispatch.aField == some("aField"));
    assert(b.dispatch.aField == no!string);
    assert(a.dispatch.aNonTemplateFunctionArity0 == some("aNonTemplateFunctionArity0"));
    assert(b.dispatch.aNonTemplateFunctionArity0 == no!string);
    assert(a.dispatch.aNonTemplateFunctionArity1("") == some("aNonTemplateFunctionArity1"));
    assert(b.dispatch.aNonTemplateFunctionArity1("") == no!string);
    assert(a.dispatch.aProperty == some("aField"));
    assert(b.dispatch.aProperty == no!string);
    a.dispatch.aProperty = "newField";
    b.dispatch.aProperty = "newField";
    assert(a.dispatch.aProperty == some("newField"));
    assert(b.dispatch.aProperty == no!string);
    assert(a.dispatch.aTemplateFunctionArity0 == some("aTemplateFunctionArity0"));
    assert(b.dispatch.aTemplateFunctionArity0 == no!string);
    assert(a.dispatch.aTemplateFunctionArity1!("") == some("aTemplateFunctionArity1"));
    assert(b.dispatch.aTemplateFunctionArity1!("") == no!string);
    assert(a.dispatch.dispatch == some("dispatch"));
    assert(b.dispatch.dispatch == no!string);
    assert(a.dispatch.aManifestConstant == some("aManifestConstant"));
    assert(b.dispatch.aManifestConstant == no!string);
    assert(a.dispatch.aStaticImmutable == some("aStaticImmutable"));
    assert(b.dispatch.aStaticImmutable == no!string);
}

unittest {
    class C {
        int i = 0;
        C mutate() {
            this.i++;
            return this;
        }
    }

    auto a = some(new C());
    auto b = a.dispatch.mutate.mutate.mutate;

    assert(a.unwrap.i == 3);
    assert(b.self.unwrap.i == 3);
}

unittest {
    struct S {
        int i = 0;
        ref S mutate() {
            i++;
            return this;
        }
    }

    auto a = some(S());
    auto b = a.dispatch.mutate.mutate.mutate;

    assert(a.unwrap.i == 3);
    assert(b.self.unwrap.i == 3);
}

unittest {
    struct B {
        int f() {
            return 8;
        }
        int m = 3;
    }
    struct A {
        B* b_;
        B* b() {
            return b_;
        }
    }

    auto a = some(new A(new B));
    auto b = some(new A);

    assert(a.dispatch.b.f == some(8));
    assert(a.dispatch.b.m == some(3));

    assert(b.dispatch.b.f == no!int);
    assert(b.dispatch.b.m == no!int);
}

unittest {
    class C {
        void method() {}
        void tmethod(T)() {}
    }
    auto c = some(new C());
    static assert(__traits(compiles, c.dispatch.method()));
    static assert(__traits(compiles, c.dispatch.tmethod!int()));
}

unittest {
    import optional: Optional, none;

    class A {
        void nonConstNonSharedMethod() {}
        void constMethod() const {}
        void sharedNonConstMethod() shared {}
        void sharedConstMethod() shared const {}
    }

    alias IA = immutable A;
    alias CA = const A;
    alias SA = shared A;
    alias SCA = shared const A;

    Optional!IA ia = new IA;
    Optional!CA ca = new CA;
    Optional!SA sa = new SA;
    Optional!SCA sca = new SA;

    static assert(!__traits(compiles, () { ia.dispatch.nonConstNonSharedMethod; } ));
    static assert(!__traits(compiles, () { ca.dispatch.nonConstNonSharedMethod; } ));
    static assert(!__traits(compiles, () { sa.dispatch.nonConstNonSharedMethod; } ));
    static assert(!__traits(compiles, () { sca.dispatch.nonConstNonSharedMethod; } ));

    static assert( __traits(compiles, () { ia.dispatch.constMethod; } ));
    static assert( __traits(compiles, () { ca.dispatch.constMethod; } ));
    static assert(!__traits(compiles, () { sa.dispatch.constMethod; } ));
    static assert(!__traits(compiles, () { sca.dispatch.constMethod; } ));

    static assert(!__traits(compiles, () { ia.dispatch.sharedNonConstMethod; } ));
    static assert(!__traits(compiles, () { ca.dispatch.sharedNonConstMethod; } ));
    static assert( __traits(compiles, () { sa.dispatch.sharedNonConstMethod; } ));
    static assert(!__traits(compiles, () { sca.dispatch.sharedNonConstMethod; } ));

    static assert( __traits(compiles, () { ia.dispatch.sharedConstMethod; } ));
    static assert(!__traits(compiles, () { ca.dispatch.sharedConstMethod; } ));
    static assert( __traits(compiles, () { sa.dispatch.sharedConstMethod; } ));
    static assert( __traits(compiles, () { sca.dispatch.sharedConstMethod; } ));
}

unittest {
    struct S {
        void f() {}
    }
    static assert(!__traits(compiles, { Dispatcher!S a; }));
    Dispatcher!S b = Dispatcher!S.init;
    static assert(!__traits(compiles, { auto c = b; }));
}
