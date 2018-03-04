module optional.dispatcher;

import optional.internal;

struct OptionalDispatcher(T, from!"std.typecons".Flag!"refOptional" isRef = from!"std.typecons".No.refOptional) {

    import std.traits: hasMember;
    import std.typecons: Yes;
    import optional: Optional;

    static if (isRef == Yes.refOptional)
        Optional!T* self;
    else
        Optional!T self;

    alias self this;

    template opDispatch(string name) if (hasMember!(T, name)) {
        import bolts.traits: hasProperty, isManifestAssignable;

        bool empty() {
            import std.traits: isPointer;
            static if (isPointer!T)
                return self.empty || self.front is null;
            else
                return self.empty;
        }
        
        static if (is(typeof(__traits(getMember, T, name)) == function))
        {
            // non template function
            auto ref opDispatch(Args...)(auto ref Args args) {
                alias C = () => mixin("self.front." ~ name)(args);
                alias R = typeof(C());
                static if (!is(R == void))
                    return empty ? OptionalDispatcher!R(no!R) : OptionalDispatcher!R(some(C()));
                else
                    if (!empty) {
                        C();
                    }
            }
        }
        else static if (hasProperty!(T, name))
        {
            import bolts.traits: propertySemantics;
            enum property = propertySemantics!(T, name);
            static if (property.canRead)
            {
                @property auto ref opDispatch()() {
                    alias C = () => mixin("self.front." ~ name);
                    alias R = typeof(C());
                    return empty ? OptionalDispatcher!R(no!R) : OptionalDispatcher!R(some(C()));
                }
            }

            static if (property.canWrite)
            {
                @property auto ref opDispatch(V)(auto ref V v) {
                    alias C = () => mixin("self.front." ~ name ~ " = v");
                    alias R = typeof(C());
                    static if (!is(R == void))
                        return empty ? OptionalDispatcher!R(no!R) : OptionalDispatcher!R(some(C()));
                    else
                        if (!empty) {
                            C();
                        }
                }
            }
        }
        else static if (isManifestAssignable!(T, name))
        {
            enum u = mixin("T." ~ name);
            alias U = typeof(u);
            auto opDispatch() {
                return empty ? OptionalDispatcher!U(no!U) : OptionalDispatcher!(U)(some!U(u));
            } 
        }
        else static if (is(typeof(mixin("self.front." ~ name))))
        {
            auto opDispatch() {
                alias C = () => mixin("self.front." ~ name);
                alias R = typeof(C());
                return empty ? OptionalDispatcher!R(no!R) : OptionalDispatcher!R(some(C()));
            }
        }
        else
        {
            // member template
            template opDispatch(Ts...) {
                enum targs = Ts.length ? "!Ts" : "";
                auto ref opDispatch(Args...)(auto ref Args args) {
                    alias C = () => mixin("self.front." ~ name ~ targs ~ "(args)");
                    alias R = typeof(C());
                    static if (!is(R == void))
                        return empty ? OptionalDispatcher!R(no!R) : OptionalDispatcher!R(some(C()));
                    else
                        if (!empty) {
                            C();
                        }
                }
            }
        }
    }
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
    struct Object {
        int f() {
            return 7;
        }
    }
    auto a = some(Object());
    auto b = no!Object;

    assert(a.dispatch.f() == some(7));
    assert(b.dispatch.f() == no!int);
}

unittest {
    struct B {
        int f() {
            return 8;
        }
        int m = 3;
    }
    struct A {
        B *b_;
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