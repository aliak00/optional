module tests.dispatcher;

import optional;

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
    import optional: none;
    struct S {
        S other() { return S(); }
    }
    auto a = some(S());
    auto d1 = a.dispatch.other;
    auto d2 = a.dispatch.other;
    static assert(!__traits(compiles, { d1 = d2; } ));
    static assert(!__traits(compiles, { d1 = Dispatcher!S.init; } ));
    static assert( __traits(compiles, { d1 = S(); } ));
    static assert( __traits(compiles, { d1 = none; } ));
}
