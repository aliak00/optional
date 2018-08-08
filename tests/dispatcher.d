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
    a.dispatch.aField.should == some("aField");
    b.dispatch.aField.should == no!string;
    a.dispatch.aNonTemplateFunctionArity0.should == some("aNonTemplateFunctionArity0");
    b.dispatch.aNonTemplateFunctionArity0.should == no!string;
    a.dispatch.aNonTemplateFunctionArity1("").should == some("aNonTemplateFunctionArity1");
    b.dispatch.aNonTemplateFunctionArity1("").should == no!string;
    a.dispatch.aProperty.should == some("aField");
    b.dispatch.aProperty.should == no!string;
    a.dispatch.aProperty = "newField";
    b.dispatch.aProperty = "newField";
    a.dispatch.aProperty.should == some("newField");
    b.dispatch.aProperty.should == no!string;
    a.dispatch.aTemplateFunctionArity0.should == some("aTemplateFunctionArity0");
    b.dispatch.aTemplateFunctionArity0.should == no!string;
    a.dispatch.aTemplateFunctionArity1!("").should == some("aTemplateFunctionArity1");
    b.dispatch.aTemplateFunctionArity1!("").should == no!string;
    a.dispatch.dispatch.should == some("dispatch");
    b.dispatch.dispatch.should == no!string;
    a.dispatch.aManifestConstant.should == some("aManifestConstant");
    b.dispatch.aManifestConstant.should == no!string;
    a.dispatch.aStaticImmutable.should == some("aStaticImmutable");
    b.dispatch.aStaticImmutable.should == no!string;
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

    a.unwrap.i.should == 3;
    b.self.unwrap.i.should == 3;
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

    a.unwrap.i.should == 3;
    b.self.unwrap.i.should == 3;
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

    a.dispatch.b.f.should == some(8);
    a.dispatch.b.m.should == some(3);

    b.dispatch.b.f.should == no!int;
    b.dispatch.b.m.should == no!int;
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
