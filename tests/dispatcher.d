module tests.dispatcher;

import std.stdio;

import optional;

class Class {
    int i = 0;

    this(int i) @nogc @safe pure {
        this.i = i;
    }

    int getI() @nogc @safe pure {
        return i;
    }

    void setI(int i) @nogc @safe pure {
        this.i = i;
    }

    Class getAnotherClass() @safe pure {
        return new Class(i);
    }

    Struct getStruct() @nogc @safe pure {
        return Struct(this.i);
    }
}

struct Struct {
    int i = 0;

    void setI(int i) @nogc @safe pure {
        this.i = i;
    }

    int getI() @nogc @safe pure {
        return i;
    }

    Class getClass() @safe pure {
        return new Class(this.i);
    }

    Struct getAnotherStruct() @nogc @safe pure {
        return Struct(this.i);
    }
}

@("Should dispatch multiple functions of a reference type")
@safe unittest {
    auto a = no!Class;
    auto b = some(new Class(3));

    assert(a.dispatch.getI == no!int());
    assert(b.dispatch.getI == some(3));

    a.dispatch.setI(7);
    b.dispatch.setI(7);

    assert(a.dispatch.getAnotherClass.i == no!int);
    assert(b.dispatch.getAnotherClass.i == some(7));
}

@("Should dispatch a function of a reference type")
@safe unittest {
    Class a;
    Class b = new Class(3);

    assert(a.dispatch.getI == no!int());
    assert(b.dispatch.getI == some(3));

    assert(b.i == 3);

    a.dispatch.setI(5);
    b.dispatch.setI(5);

    assert(b.i == 5);
}

@("Should dispatch multiple functions of a pointer type")
@safe unittest {
    auto a = no!(Struct*);
    auto b = some(new Struct(3));

    assert(a.dispatch.getI == no!int());
    assert(b.dispatch.getI == some(3));

    a.dispatch.setI(7);
    b.dispatch.setI(7);

    assert(a.dispatch.getAnotherStruct.i == no!int);
    assert(b.dispatch.getAnotherStruct.i == some(7));
}

@("Should dispatch a function of a pointer type")
@safe unittest {
    Struct* a;
    Struct* b = new Struct(3);

    assert(a.dispatch.getI == no!int());
    assert(b.dispatch.getI == some(3));

    assert(b.i == 3);

    a.dispatch.setI(5);
    b.dispatch.setI(5);

    assert(b.i == 5);
}

@("Should dispatch to different member types")
@safe unittest {
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
        string aTemplateFunctionArity0()() {
            return "aTemplateFunctionArity0";
        }
        string aTemplateFunctionArity1(string T)() {
            return "aTemplateFunctionArity1";
        }
        string dispatch() {
            return "dispatch";
        }
    }

    auto a = some(A());
    auto b = no!A;
    assert(a.dispatch.aField == some("aField"));
    assert(b.dispatch.aField == no!string);
    assert(a.dispatch.aNonTemplateFunctionArity0 == some("aNonTemplateFunctionArity0"));
    assert(b.dispatch.aNonTemplateFunctionArity0 == no!string);
    assert(a.dispatch.aNonTemplateFunctionArity1("") == some("aNonTemplateFunctionArity1"));
    assert(b.dispatch.aNonTemplateFunctionArity1("") == no!string);
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

@("Should work for all qualifiers")
@safe unittest {
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

@nogc @safe pure unittest {
    auto a = some(Struct(7));
    auto b = no!Struct;
    assert(a.dispatch.i == some(7));
    assert(a.dispatch.getI == some(7));
    assert(a.dispatch.getAnotherStruct.i == some(7));
    assert(b.dispatch.i == no!int);
    assert(b.dispatch.getI == no!int);
    assert(b.dispatch.getAnotherStruct.i == no!int);
}
