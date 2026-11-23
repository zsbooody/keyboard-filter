#include "key_sequence.h"

#include <cassert>
#include <cstdio>
#include <initializer_list>

int main() {
    assert(isLearningBounce(34));
    assert(isLearningBounce(35));
    assert(!isLearningBounce(36));
    KeySequence key;

    // A protected press can lose an early hardware duplicate and still keep its release.
    key.press(1000, true, false);
    assert(!key.isRepeat(1179));
    assert(key.blocksDown(key.isRepeat(1179)));
    assert(key.isRepeat(1180));
    for (const auto now : {1300u, 1333u, 1366u, 3000u}) {
        assert(!key.blocksDown(key.isRepeat(now)));
    }
    assert(!key.release());
    assert(!key.isDown);

    // Neither the repeat nor the release of a rejected first down reaches the foreground app.
    key.press(3010, true, true);
    assert(key.blocksDown(key.isRepeat(3040)));
    assert(key.blocksDown(key.isRepeat(4000)));
    assert(key.release());
    assert(!key.release());

    // An unprotected key keeps its initial policy until release.
    key.press(4000, false, false);
    assert(!key.blocksDown(key.isRepeat(4010)));
    assert(!key.release());

    std::puts("PASS Windows key pairing, repeat timing, press policy and learning boundary");
}
