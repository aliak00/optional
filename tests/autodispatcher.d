module tests.autodispatcher;

import optional;

@("Should dispatch")
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
        string autoDispatch() {
            return "autoDispatch";
        }
    }

    auto a = some(A());
    auto b = no!A;
    assert(a.autoDispatch.aField == some("aField"));
    assert(b.autoDispatch.aField == no!string);
    assert(a.autoDispatch.aNonTemplateFunctionArity0 == some("aNonTemplateFunctionArity0"));
    assert(b.autoDispatch.aNonTemplateFunctionArity0 == no!string);
    assert(a.autoDispatch.aNonTemplateFunctionArity1("") == some("aNonTemplateFunctionArity1"));
    assert(b.autoDispatch.aNonTemplateFunctionArity1("") == no!string);
    assert(a.autoDispatch.aProperty == some("aField"));
    assert(b.autoDispatch.aProperty == no!string);
    a.autoDispatch.aProperty = "newField";
    b.autoDispatch.aProperty = "newField";
    assert(a.autoDispatch.aProperty == some("newField"));
    assert(b.autoDispatch.aProperty == no!string);
    assert(a.autoDispatch.aTemplateFunctionArity0 == some("aTemplateFunctionArity0"));
    assert(b.autoDispatch.aTemplateFunctionArity0 == no!string);
    assert(a.autoDispatch.aTemplateFunctionArity1!("") == some("aTemplateFunctionArity1"));
    assert(b.autoDispatch.aTemplateFunctionArity1!("") == no!string);
    assert(a.autoDispatch.autoDispatch == some("autoDispatch"));
    assert(b.autoDispatch.autoDispatch == no!string);
    assert(a.autoDispatch.aManifestConstant == some("aManifestConstant"));
    assert(b.autoDispatch.aManifestConstant == no!string);
    assert(a.autoDispatch.aStaticImmutable == some("aStaticImmutable"));
    assert(b.autoDispatch.aStaticImmutable == no!string);
}

@("Should mutatue original optional with reference type")
unittest {
    class C {
        int i = 0;
        C mutate() {
            this.i++;
            return this;
        }
    }

    auto a = some(new C());
    auto b = a.autoDispatch.mutate.mutate.mutate;

    assert(a.unwrap.i == 3);
}

@("Should mutatue original optional with value type")
unittest {
    struct S {
        int i = 0;
        ref S mutate() {
            i++;
            return this;
        }
    }

    auto a = some(S());
    auto b = a.autoDispatch.mutate.mutate.mutate;

    assert(a.unwrap.i == 3);
}

@("Should be safe with null pointer members")
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

    assert(a.autoDispatch.b.f == some(8));
    assert(a.autoDispatch.b.m == some(3));

    assert(b.autoDispatch.b.f == no!int);
    assert(b.autoDispatch.b.m == no!int);
}

@("Should allow dispatching of template functions")
unittest {
    class C {
        void method() {}
        void tmethod(T)() {}
    }
    auto c = some(new C());

    static assert(__traits(compiles, c.autoDispatch.method()));
    static assert(__traits(compiles, c.autoDispatch.tmethod!int()));
}

@("Should work for all qualifiers")
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

    static assert(!__traits(compiles, () { ia.autoDispatch.nonConstNonSharedMethod; } ));
    static assert(!__traits(compiles, () { ca.autoDispatch.nonConstNonSharedMethod; } ));
    static assert(!__traits(compiles, () { sa.autoDispatch.nonConstNonSharedMethod; } ));
    static assert(!__traits(compiles, () { sca.autoDispatch.nonConstNonSharedMethod; } ));

    static assert( __traits(compiles, () { ia.autoDispatch.constMethod; } ));
    static assert( __traits(compiles, () { ca.autoDispatch.constMethod; } ));
    static assert(!__traits(compiles, () { sa.autoDispatch.constMethod; } ));
    static assert(!__traits(compiles, () { sca.autoDispatch.constMethod; } ));

    static assert(!__traits(compiles, () { ia.autoDispatch.sharedNonConstMethod; } ));
    static assert(!__traits(compiles, () { ca.autoDispatch.sharedNonConstMethod; } ));
    static assert( __traits(compiles, () { sa.autoDispatch.sharedNonConstMethod; } ));
    static assert(!__traits(compiles, () { sca.autoDispatch.sharedNonConstMethod; } ));

    static assert( __traits(compiles, () { ia.autoDispatch.sharedConstMethod; } ));
    static assert(!__traits(compiles, () { ca.autoDispatch.sharedConstMethod; } ));
    static assert( __traits(compiles, () { sa.autoDispatch.sharedConstMethod; } ));
    static assert( __traits(compiles, () { sca.autoDispatch.sharedConstMethod; } ));
}
