// Corobs is pure: the library target links nothing, so no database, network or LLM client can be
// reached from it. CMakeLists.txt also refuses to configure if it ever does.
#include <gtest/gtest.h>

#include <string>

#include "corobs_test_config.hpp"

TEST(Purity, TheLibraryTargetLinksNothing) {
    EXPECT_EQ(std::string(COROBS_LINK_LIBRARIES), "");
    EXPECT_EQ(std::string(COROBS_INTERFACE_LINK_LIBRARIES), "");
}
