module tests.dispatcher;

import optional;
import unit_threaded;

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
    a.dispatch.aField.shouldEqual(some("aField"));
    b.dispatch.aField.shouldEqual(no!string);
    a.dispatch.aNonTemplateFunctionArity0.shouldEqual(some("aNonTemplateFunctionArity0"));
    b.dispatch.aNonTemplateFunctionArity0.shouldEqual(no!string);
    a.dispatch.aNonTemplateFunctionArity1("").shouldEqual(some("aNonTemplateFunctionArity1"));
    b.dispatch.aNonTemplateFunctionArity1("").shouldEqual(no!string);
    a.dispatch.aProperty.shouldEqual(some("aField"));
    b.dispatch.aProperty.shouldEqual(no!string);
    a.dispatch.aProperty = "newField";
    b.dispatch.aProperty = "newField";
    a.dispatch.aProperty.shouldEqual(some("newField"));
    b.dispatch.aProperty.shouldEqual(no!string);
    a.dispatch.aTemplateFunctionArity0.shouldEqual(some("aTemplateFunctionArity0"));
    b.dispatch.aTemplateFunctionArity0.shouldEqual(no!string);
    a.dispatch.aTemplateFunctionArity1!("").shouldEqual(some("aTemplateFunctionArity1"));
    b.dispatch.aTemplateFunctionArity1!("").shouldEqual(no!string);
    a.dispatch.dispatch.shouldEqual(some("dispatch"));
    b.dispatch.dispatch.shouldEqual(no!string);
    a.dispatch.aManifestConstant.shouldEqual(some("aManifestConstant"));
    b.dispatch.aManifestConstant.shouldEqual(no!string);
    a.dispatch.aStaticImmutable.shouldEqual(some("aStaticImmutable"));
    b.dispatch.aStaticImmutable.shouldEqual(no!string);
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
    auto b = a.dispatch.mutate.mutate.mutate;

    assert(a.unwrap.i == 3);
    assert(b.self.unwrap.i == 3);
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
    auto b = a.dispatch.mutate.mutate.mutate;

    assert(a.unwrap.i == 3);
    assert(b.self.unwrap.i == 3);
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

    assert(a.dispatch.b.f == some(8));
    assert(a.dispatch.b.m == some(3));

    assert(b.dispatch.b.f == no!int);
    assert(b.dispatch.b.m == no!int);
}

@("Should allow dispatching of template functions")
unittest {
    class C {
        void method() {}
        void tmethod(T)() {}
    }
    auto c = some(new C());
    static assert(__traits(compiles, c.dispatch.method()));
    static assert(__traits(compiles, c.dispatch.tmethod!int()));
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

@("Should not allow copy assign or copy construct")
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
