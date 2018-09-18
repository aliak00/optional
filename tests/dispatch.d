module tests.dispatch;

import std.stdio;

import optional;

class Class {
    int i = 0;

    this(int i) @nogc @safe pure { this.i = i;}
    int getI() @nogc @safe pure { return i;}
    void setI(int i) @nogc @safe pure { this.i = i; }

    Struct getStruct() @nogc @safe pure { return Struct(this.i); }
    Class getClass() @safe pure { return new Class(this.i); }

    Struct* getStructRef() @safe pure { return new Struct(this.i); }
    Class getNullClass() @nogc @safe pure { return null; }
    Struct* getNullStruct() @nogc @safe pure { return null; }
}

struct Struct {
    int i = 0;

    this(int i) @nogc @safe pure { this.i = i;}
    int getI() @nogc @safe pure { return i;}
    void setI(int i) @nogc @safe pure { this.i = i; }

    Struct getStruct() @nogc @safe pure { return Struct(this.i);}
    Class getClass() @safe pure { return new Class(this.i); }

    Struct* getStructRef() @safe pure { return new Struct(this.i);}
    Class getNullClass() @nogc @safe pure { return null; }
    Struct* getNullStruct() @nogc @safe pure { return null; }
}

@("Should dispatch multiple functions of a reference type")
@safe unittest {
    auto a = no!Class;
    auto b = some(new Class(3));

    assert(a.dispatch.getI == no!int());
    assert(b.dispatch.getI == some(3));

    a.dispatch.setI(7);
    b.dispatch.setI(7);

    assert(a.dispatch.getClass.i == no!int);
    assert(b.dispatch.getClass.i == some(7));
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

    assert(a.dispatch.getStruct.i == no!int);
    assert(b.dispatch.getStruct.i == some(7));
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

@("Should be safe nogc and pure")
@nogc @safe pure unittest {
    auto a = some(Struct(7));
    auto b = no!Struct;
    assert(a.dispatch.i == some(7));
    assert(a.dispatch.getI == some(7));
    assert(a.dispatch.getStruct.i == some(7));
    assert(b.dispatch.i == no!int);
    assert(b.dispatch.getI == no!int);
    assert(b.dispatch.getStruct.i == no!int);
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

    auto a = some(new Struct(3));
    auto b = some(new Struct(7));

    assert(a.dispatch.getStruct.getStructRef.i == some(3));
    assert(a.dispatch.getStruct.getStructRef.getI == some(3));

    assert(b.dispatch.getStruct.getNullStruct.i == no!int);
    assert(b.dispatch.getStruct.getNullStruct.getI == no!int);
}

@("Should dispatch template functions")
unittest {
    class C {
        void method() {}
        void tmethod(T)() {}
    }
    auto c = some(new C());

    static assert(__traits(compiles, c.dispatch.method()));
    static assert(__traits(compiles, c.dispatch.tmethod!int()));
}

@("Should flatten inner optional members")
unittest {
    class Residence {
        auto numberOfRooms = 1;
    }
    class Person {
        Optional!Residence residence = new Residence();
    }

    auto john = some(new Person());

    auto n = john.dispatch.residence.numberOfRooms;

    assert(n == some(1));
}

@("Should use Optional.toString")
unittest {
    import std.format;
    assert(some(Struct(3)).dispatch.i.toString == "[3]");
}

@("Should work with some deep nesting")
unittest {
    assert(
        some(new Class(10))
            .dispatch
            .getStruct
            .getClass
            .getStructRef
            .i == some(10)
    );

    assert(
        some(new Class(10))
            .dispatch
            .getNullStruct
            .getNullClass
            .getNullClass
            .i == no!int
    );
}
