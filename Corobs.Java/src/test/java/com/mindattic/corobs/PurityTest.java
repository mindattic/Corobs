package com.mindattic.corobs;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** COROBS is pure: the library depends on nothing beyond java.base; JUnit and Jackson are test scope only. */
class PurityTest {

    private static Path project(String property, String fallback) {
        String p = System.getProperty(property);
        return Path.of(p != null ? p : fallback);
    }

    @Test
    void every_maven_dependency_is_test_scoped() throws IOException {
        String pom = Files.readString(project("corobs.pom", "pom.xml"));
        Matcher m = Pattern.compile("<dependency>(.*?)</dependency>", Pattern.DOTALL).matcher(pom);
        int count = 0;
        while (m.find()) {
            count++;
            assertTrue(m.group(1).contains("<scope>test</scope>"), "non-test dependency in pom.xml: " + m.group(1).trim());
        }
        assertTrue(count > 0, "precondition: pom.xml declares the test dependencies");
    }

    @Test
    void the_module_requires_nothing() throws IOException {
        Path pom = project("corobs.pom", "pom.xml");
        String module = Files.readString(pom.resolveSibling("src/main/java/module-info.java"));
        assertFalse(module.contains("requires"), "module-info.java must not require any module beyond java.base");
    }
}
