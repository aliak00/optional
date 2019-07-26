module compattests.vibe;

import optional;

@("Should serialize and deserialize to json with vibe.data.serialization")
unittest {
    import vibe.data.json;
    import vibe.data.serialization;

    struct User {
        int a;
        Optional!string b;
    }

    auto user0 = User(1, some("boo"));
    auto json0 = `{"a":1,"b":"boo"}`.parseJsonString;
    auto json1 = user0.serializeToJson;
    auto user1 = json0.deserializeJson!User;

    assert(user0 == user1);
    assert(json0 == json1);
}
