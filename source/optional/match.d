/**
    Provides a match function for optional types
*/
module optional.match;

import optional.optional;

/**
    Calls an appropriate handler depending on if the optional has a value or not

    Params:
        opt = The optional to call match on
        handlers = 2 predicates, one that takes the underlying optional type and another that names nothing
*/
public template match(handlers...) if (handlers.length == 2) {
	auto match(T)(inout auto ref Optional!T opt) {

        static if (is(typeof(handlers[0](opt.front)))) {
            alias someHandler = handlers[0];
            alias noHandler = handlers[1];
        } else {
            alias someHandler = handlers[1];
            alias noHandler = handlers[0];
        }

        import bolts: isFunctionOver;

        static assert(
            isFunctionOver!(someHandler, T) && isFunctionOver!(noHandler),
            "One handler must have one parameter of type '" ~ T.stringof ~ "' and the other no parameter"
        );

        alias RS = typeof(someHandler(opt.front));
        alias RN = typeof(noHandler());

        static assert(
            is(RS == RN),
            "Expected two handlers to return same type, found type '" ~ RS.stringof ~ "' and type '" ~ RN.stringof ~ "'",
        );

        if (opt.empty) {
            return noHandler();
        } else {
            return someHandler(opt.front);
        }
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
