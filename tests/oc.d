module tests.oc;

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

@("Should oc multiple functions of a reference type")
@safe unittest {
    auto a = no!Class;
    auto b = some(new Class(3));

    assert(oc(a).getI == no!int());
    assert(oc(b).getI == some(3));

    oc(a).setI(7);
    oc(b).setI(7);

    assert(oc(a).getClass.i == no!int);
    assert(oc(b).getClass.i == some(7));
}

@("Should oc a function of a reference type")
@safe unittest {
    Class a;
    Class b = new Class(3);

    assert(oc(a).getI == no!int());
    assert(oc(b).getI == some(3));

    assert(b.i == 3);

    oc(a).setI(5);
    oc(b).setI(5);

    assert(b.i == 5);
}

@("Should oc multiple functions of a pointer type")
@safe unittest {
    auto a = no!(Struct*);
    auto b = some(new Struct(3));

    assert(oc(a).getI == no!int());
    assert(oc(b).getI == some(3));

    oc(a).setI(7);
    oc(b).setI(7);

    assert(oc(a).getStruct.i == no!int);
    assert(oc(b).getStruct.i == some(7));
}

@("Should oc a function of a pointer type")
@safe unittest {
    Struct* a;
    Struct* b = new Struct(3);

    assert(oc(a).getI == no!int());
    assert(oc(b).getI == some(3));

    assert(b.i == 3);

    oc(a).setI(5);
    oc(b).setI(5);

    assert(b.i == 5);
}

@("Should oc to different member types")
@safe @nogc unittest {
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
        string oc() {
            return "oc";
        }
    }

    auto a = some(A());
    auto b = no!A;
    assert(oc(a).aField == some("aField"));
    assert(oc(b).aField == no!string);
    assert(oc(a).aNonTemplateFunctionArity0 == some("aNonTemplateFunctionArity0"));
    assert(oc(b).aNonTemplateFunctionArity0 == no!string);
    assert(oc(a).aNonTemplateFunctionArity1("") == some("aNonTemplateFunctionArity1"));
    assert(oc(b).aNonTemplateFunctionArity1("") == no!string);
    assert(oc(a).aTemplateFunctionArity0 == some("aTemplateFunctionArity0"));
    assert(oc(b).aTemplateFunctionArity0 == no!string);
    assert(oc(a).aTemplateFunctionArity1!("") == some("aTemplateFunctionArity1"));
    assert(oc(b).aTemplateFunctionArity1!("") == no!string);
    assert(oc(a).oc == some("oc"));
    assert(oc(b).oc == no!string);
    assert(oc(a).aManifestConstant == some("aManifestConstant"));
    assert(oc(b).aManifestConstant == no!string);
    assert(oc(a).aStaticImmutable == some("aStaticImmutable"));
    assert(oc(b).aStaticImmutable == no!string);
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

    static assert(!__traits(compiles, () { oc(ia).nonConstNonSharedMethod; } ));
    static assert(!__traits(compiles, () { oc(ca).nonConstNonSharedMethod; } ));
    static assert(!__traits(compiles, () { oc(sa).nonConstNonSharedMethod; } ));
    static assert(!__traits(compiles, () { oc(sca).nonConstNonSharedMethod; } ));

    static assert( __traits(compiles, () { oc(ia).constMethod; } ));
    static assert( __traits(compiles, () { oc(ca).constMethod; } ));
    static assert(!__traits(compiles, () { oc(sa).constMethod; } ));
    static assert(!__traits(compiles, () { oc(sca).constMethod; } ));

    static assert(!__traits(compiles, () { oc(ia).sharedNonConstMethod; } ));
    static assert(!__traits(compiles, () { oc(ca).sharedNonConstMethod; } ));
    static assert( __traits(compiles, () { oc(sa).sharedNonConstMethod; } ));
    static assert(!__traits(compiles, () { oc(sca).sharedNonConstMethod; } ));

    static assert( __traits(compiles, () { oc(ia).sharedConstMethod; } ));
    static assert(!__traits(compiles, () { oc(ca).sharedConstMethod; } ));
    static assert( __traits(compiles, () { oc(sa).sharedConstMethod; } ));
    static assert( __traits(compiles, () { oc(sca).sharedConstMethod; } ));
}

@("Should be safe nogc and pure")
@nogc @safe pure unittest {
    auto a = some(Struct(7));
    auto b = no!Struct;
    assert(oc(a).i == some(7));
    assert(oc(a).getI == some(7));
    assert(oc(a).getStruct.i == some(7));
    assert(oc(b).i == no!int);
    assert(oc(b).getI == no!int);
    assert(oc(b).getStruct.i == no!int);
}

@("Should be safe with null pointer members")
@safe unittest {
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

    assert(oc(a).getStruct.getStructRef.i == some(3));
    assert(oc(a).getStruct.getStructRef.getI == some(3));

    assert(oc(b).getStruct.getNullStruct.i == no!int);
    assert(oc(b).getStruct.getNullStruct.getI == no!int);
}

@("Should chain template functions")
unittest {
    class C {
        void method() {}
        void tmethod(T)() {}
    }
    auto c = some(new C());

    static assert(__traits(compiles, oc(c).method()));
    static assert(__traits(compiles, oc(c).tmethod!int()));
}

@("Should flatten inner optional members")
@safe unittest {
    class Residence {
        auto numberOfRooms = 1;
    }
    class Person {
        Optional!Residence residence;
    }

    auto john = some(new Person());
    auto n = oc(john).residence.numberOfRooms;

    assert(n == no!int);

    oc(john).residence = new Residence();
    n = oc(john).residence.numberOfRooms;

    assert(n == some(1));
}

@("Should use Optional.toString")
@safe unittest {
    assert(some(Struct(3)).oc.i.toString == "[3]");
}

@("Should work with some deep nesting")
@safe unittest {
    assert(
        some(new Class(10))
            .oc
            .getStruct
            .getClass
            .getStructRef
            .i == some(10)
    );

    assert(
        some(new Class(10))
            .oc
            .getNullStruct
            .getNullClass
            .getNullClass
            .i == no!int
    );
}

@("Should work on std.typecons.Nullable")
@safe @nogc unittest {
    import std.typecons;
    auto a = nullable(Struct(3));
    auto b = Nullable!Struct.init;

    assert(oc(a).i == some(3));
    assert(oc(b).i == no!int);
}

@("Result of optional chain must be pattern matchable")
@safe @nogc unittest {
	static struct TypeA {
		string x;
	}
	static struct TypeB {
		auto getValue() {
			return TypeA("yes");
		}
	}
	auto b = some(TypeB());
	const result = oc(b).getValue().match!(
		(a) => a.x,
		() => "no"
	);
	assert(result == "yes");
}
