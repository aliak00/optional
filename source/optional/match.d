/**
    Provides a match function for optional types
*/
module optional.match;

import optional.optional;

/**
    Calls an appropriate handler depending on if the optional has a value or not

    If either handler returns void, the return type of match is void.

    Params:
        opt = The optional to call match on
        handlers = 2 predicates, one that takes the underlying optional type and another that names nothing
*/
public template match(handlers...) if (handlers.length == 2) {
	auto match(O)(auto ref O opt) {
        import optional.traits: isOptionalChain, isOptional;
        import std.range: ElementType, isInputRange;
        static if (isOptionalChain!O) {
			return .match!handlers(opt.value);
        // Check for isOptional as well because a const(Option!T) is not an input range, but it is an optional.
        } else static if (isInputRange!O || isOptional!O) {
            alias T = ElementType!O;
	        static if (is(typeof(handlers[0](opt.front)))) {
	            alias someHandler = handlers[0];
	            alias noHandler = handlers[1];
				return doMatch!(someHandler, noHandler, T)(opt);
	        } else static if (is(typeof(handlers[0]()))) {
	            alias someHandler = handlers[1];
	            alias noHandler = handlers[0];
				return doMatch!(someHandler, noHandler, T)(opt);
	        } else {
				// One of these two is causing a compile error.
				// Let's call them so the compiler can show a proper error warning.
				failOnCompileError!(handlers[0], T);
				failOnCompileError!(handlers[1], T);
			}
		} else {
			static assert(0, "Cannot match!() on a " ~ O.stringof);
		}
	}
}

private auto doMatch(alias someHandler, alias noHandler, T, O)(ref auto O opt) {
	alias SomeHandlerReturn = typeof(someHandler(T.init));
	alias NoHandlerReturn = typeof(noHandler());
	enum isVoidReturn = is(typeof(someHandler(T.init)) == void) || is(typeof(noHandler()) == void);

	static assert(
		is(SomeHandlerReturn == NoHandlerReturn) || isVoidReturn,
		"Expected two handlers to return same type, found type '" ~ SomeHandlerReturn.stringof ~ "' and type '" ~ NoHandlerReturn.stringof ~ "'",
	);

	if (opt.empty) {
		static if (isVoidReturn) {
			noHandler();
		} else {
			return noHandler();
		}
	} else {
		static if (isVoidReturn) {
			someHandler(opt.front);
		} else {
			return someHandler(opt.front);
		}
	}
}

/**
Prints out the correct compile error if the handler cannot be compiled.
*/
private void failOnCompileError(alias handler, T)() {
	static if (!is(typeof(handler(T.init))) && !is(typeof(handler()))) {
		cast(void) handler(T.init);
	}
}

///
@("Example of match()")
@nogc @safe unittest {
    auto a = some(3);
    auto b = no!int;

    auto ra = a.match!(
        (int a) => "yes",
        () => "no",
    );

    auto rb = b.match!(
        (a) => "yes",
        () => "no",
    );

    assert(ra == "yes");
    assert(rb == "no");
}
