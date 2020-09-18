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
	auto match(O)(O opt) {
		static if (is(O == Optional!T, T)) {
	        static if (is(typeof(handlers[0](opt.front)))) {
	            alias someHandler = handlers[0];
	            alias noHandler = handlers[1];
	        } else {
	            alias someHandler = handlers[1];
	            alias noHandler = handlers[0];
	        }

	        alias SomeHandlerReturn = typeof(someHandler(opt.front));
	        alias NoHandlerReturn = typeof(noHandler());
	        enum isVoidReturn = is(SomeHandlerReturn == void) || is(NoHandlerReturn == void);

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
		} else static if (is(typeof(opt.value) == Optional!T, T)) {
			return opt.valueMatch!handlers;
		} else {
			pragma(msg, "Type of: " ~ typeof(opt.value).stringof);
			static assert(0, "Cannot match!() on a " ~ O.stringof);
		}
	}
}

private template valueMatch(handlers...) if (handlers.length == 2) {
	auto valueMatch(O)(ref O opt) {
		return opt.value.match!handlers;
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
