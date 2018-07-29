module optional.dispatcher;

import optional.internal;

// struct OptionalDispatcher(T, from!"std.typecons".Flag!"isRef" isRef = from!"std.typecons".No.isRef) {

//     import std.traits: hasMember;
//     import std.typecons: Yes;
//     import optional: Optional;

//     static if (isRef)
//         Optional!T* self;
//     else
//         Optional!T self;

//     alias self this;

//     template opDispatch(string name) if (hasMember!(T, name)) {
//         import bolts.traits: hasProperty, isManifestAssignable;
//         import optional: no, some;

//         bool empty() {
//             import std.traits: isPointer;
//             static if (isPointer!T)
//                 return self.empty || self.front is null;
//             else
//                 return self.empty;
//         }

//         static string returnDance(string call) {
//             return "alias C = () => " ~ call ~ ";" ~
//                 q{
//                     alias R = typeof(C());
//                     static if (!is(R == void))
//                         return empty ? OptionalDispatcher!R(no!R) : OptionalDispatcher!R(some(C()));
//                     else
//                         if (!empty) {
//                             C();
//                         }
//             };
//         }
        
//         static if (is(typeof(__traits(getMember, T, name)) == function))
//         {
//             // non template function
//             auto ref opDispatch(Args...)(auto ref Args args) {
//                 mixin(returnDance("self.front." ~ name ~ "(args)"));
//             }
//         }
//         else static if (hasProperty!(T, name))
//         {
//             import bolts.traits: propertySemantics;
//             enum property = propertySemantics!(T, name);
//             static if (property.canRead)
//             {
//                 @property auto ref opDispatch()() {
//                     mixin(returnDance("self.front." ~ name));
//                 }
//             }

//             static if (property.canWrite)
//             {
//                 @property auto ref opDispatch(V)(auto ref V v) {
//                     mixin(returnDance("self.front." ~ name ~ " = v"));
//                 }
//             }
//         }
//         else static if (isManifestAssignable!(T, name))
//         {
//             enum u = mixin("T." ~ name);
//             alias U = typeof(u);
//             auto opDispatch() {
//                 return empty ? OptionalDispatcher!U(no!U) : OptionalDispatcher!(U)(some!U(u));
//             } 
//         }
//         else static if (is(typeof(mixin("self.front." ~ name))))
//         {
//             auto opDispatch() {
//                 mixin(returnDance("self.front." ~ name));
//             }
//         }
//         else
//         {
//             // member template
//             template opDispatch(Ts...) {
//                 enum targs = Ts.length ? "!Ts" : "";
//                 auto ref opDispatch(Args...)(auto ref Args args) {
//                     mixin(returnDance("self.front." ~ name ~ targs ~ "(args)"));
//                 }
//             }
//         }
//     }
// }

// unittest {
//     import optional: no, some;

//     struct A {
//         enum aManifestConstant = "aManifestConstant";
//         static immutable aStaticImmutable = "aStaticImmutable";
//         auto aField = "aField";
//         auto aNonTemplateFunctionArity0() {
//             return "aNonTemplateFunctionArity0";
//         }
//         auto aNonTemplateFunctionArity1(string value) {
//             return "aNonTemplateFunctionArity1";
//         }
//         @property string aProperty() {
//             return aField;
//         }
//         @property void aProperty(string value) {
//             aField = value;
//         }
//         string aTemplateFunctionArity0()() {
//             return "aTemplateFunctionArity0";
//         }
//         string aTemplateFunctionArity1(string T)() {
//             return "aTemplateFunctionArity1";
//         }
//         string dispatch() {
//             return "dispatch";
//         }

//         // static int * p = new int;
//         // static immutable int * nullPointer = null;
//         // static immutable int * nonNullPointer = new int(3);
//     }

//     import bolts.traits: isManifestAssignable;

//     auto a = some(A());
//     auto b = no!A;
//     assert(a.dispatch.aField == some("aField"));
//     assert(b.dispatch.aField == no!string);
//     assert(a.dispatch.aNonTemplateFunctionArity0 == some("aNonTemplateFunctionArity0"));
//     assert(b.dispatch.aNonTemplateFunctionArity0 == no!string);
//     assert(a.dispatch.aNonTemplateFunctionArity1("") == some("aNonTemplateFunctionArity1"));
//     assert(b.dispatch.aNonTemplateFunctionArity1("") == no!string);
//     assert(a.dispatch.aProperty == some("aField"));
//     assert(b.dispatch.aProperty == no!string);
//     a.dispatch.aProperty = "newField";
//     b.dispatch.aProperty = "newField";
//     assert(a.dispatch.aProperty == some("newField"));
//     assert(b.dispatch.aProperty == no!string);
//     assert(a.dispatch.aTemplateFunctionArity0 == some("aTemplateFunctionArity0"));
//     assert(b.dispatch.aTemplateFunctionArity0 == no!string);
//     assert(a.dispatch.aTemplateFunctionArity1!("") == some("aTemplateFunctionArity1"));
//     assert(b.dispatch.aTemplateFunctionArity1!("") == no!string);
//     assert(a.dispatch.dispatch == some("dispatch"));
//     assert(b.dispatch.dispatch == no!string);
//     assert(a.dispatch.aManifestConstant == some("aManifestConstant"));
//     assert(b.dispatch.aManifestConstant == no!string);
//     assert(a.dispatch.aStaticImmutable == some("aStaticImmutable"));
//     assert(b.dispatch.aStaticImmutable == no!string);
// }

// unittest {
//     import optional: no, some;

//     struct Object {
//         int f() {
//             return 7;
//         }
//     }
//     auto a = some(Object());
//     auto b = no!Object;

//     assert(a.dispatch.f() == some(7));
//     assert(b.dispatch.f() == no!int);
// }

// unittest {
//     import optional: no, some;

//     struct B {
//         int f() {
//             return 8;
//         }
//         int m = 3;
//     }
//     struct A {
//         B *b_;
//         B* b() {
//             return b_;
//         }
//     }

//     auto a = some(new A(new B));
//     auto b = some(new A);

//     assert(a.dispatch.b.f == some(8));
//     assert(a.dispatch.b.m == some(3));

//     assert(b.dispatch.b.f == no!int);
//     assert(b.dispatch.b.m == no!int);
// }

// unittest {

//     import optional: some;

//     class C {
//         void method() {}
//         void tmethod(T)() {}
//     }
//     auto c = some(new C());
//     static assert(__traits(compiles, c.dispatch.method()));
//     static assert(__traits(compiles, c.dispatch.tmethod!int()));
// }

// unittest {
//     import optional: Optional, none;

//     class A {
//         void nonConstNonSharedMethod() {}
//         void constMethod() const {}
//         void sharedNonConstMethod() shared {}
//         void sharedConstMethod() shared const {}
//     }

//     alias IA = immutable A;
//     alias CA = const A;
//     alias SA = shared A;
//     alias SCA = shared const A;

//     Optional!IA ia;
//     Optional!CA ca;
//     Optional!SA sa;
//     Optional!SCA sca;

//     ia = none;
//     ca = none;
//     sa = none;
//     sca = none;

//     ia = new IA;
//     ca = new CA;
//     sa = new SA;
//     sca = new SA;

//     static assert(!__traits(compiles, () { ia.dispatch.nonConstNonSharedMethod; } ));
//     static assert(!__traits(compiles, () { ca.dispatch.nonConstNonSharedMethod; } ));
//     static assert(!__traits(compiles, () { sa.dispatch.nonConstNonSharedMethod; } ));
//     static assert(!__traits(compiles, () { sca.dispatch.nonConstNonSharedMethod; } ));

//     static assert( __traits(compiles, () { ia.dispatch.constMethod; } ));
//     static assert( __traits(compiles, () { ca.dispatch.constMethod; } ));
//     static assert(!__traits(compiles, () { sa.dispatch.constMethod; } ));
//     static assert(!__traits(compiles, () { sca.dispatch.constMethod; } ));

//     static assert(!__traits(compiles, () { ia.dispatch.sharedNonConstMethod; } ));
//     static assert(!__traits(compiles, () { ca.dispatch.sharedNonConstMethod; } ));
//     static assert( __traits(compiles, () { sa.dispatch.sharedNonConstMethod; } ));
//     static assert(!__traits(compiles, () { sca.dispatch.sharedNonConstMethod; } ));

//     static assert( __traits(compiles, () { ia.dispatch.sharedConstMethod; } ));
//     static assert(!__traits(compiles, () { ca.dispatch.sharedConstMethod; } ));
//     static assert( __traits(compiles, () { sa.dispatch.sharedConstMethod; } ));
//     static assert( __traits(compiles, () { sca.dispatch.sharedConstMethod; } ));
// }
