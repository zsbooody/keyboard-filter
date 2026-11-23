#pragma once

#include <cstdint>

inline constexpr int kLearnBounceMs = 35;

inline bool isLearningBounce(std::uint64_t elapsedMs) {
    return elapsedMs <= kLearnBounceMs;
}

struct KeySequence {
    static constexpr std::uint64_t repeatDelayMs = 180;

    std::uint64_t startedAt = 0;
    bool isDown = false;
    bool protectedKey = false;
    bool suppressed = false;

    void press(std::uint64_t now, bool protect, bool suppress) {
        startedAt = now;
        isDown = true;
        protectedKey = protect;
        suppressed = suppress;
    }

    bool isRepeat(std::uint64_t now) const {
        return isDown && now - startedAt >= repeatDelayMs;
    }

    bool blocksDown(bool repeat) const {
        return suppressed || (protectedKey && !repeat);
    }

    bool release() {
        const bool block = suppressed;
        *this = {};
        return block;
    }
};
