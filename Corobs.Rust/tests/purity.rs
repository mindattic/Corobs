//! COROBS is pure: the library depends on nothing, so no database, network or LLM client can ever
//! be reached from it. Only tests may have dependencies.

use std::fs;
use std::path::Path;

#[test]
fn the_library_depends_on_nothing() {
    let toml =
        fs::read_to_string(Path::new(env!("CARGO_MANIFEST_DIR")).join("Cargo.toml")).unwrap();
    let mut section = String::new();
    let mut seen_dependencies = false;
    for raw in toml.lines() {
        let line = raw.trim();
        if line.starts_with('[') {
            section = line.to_string();
            seen_dependencies |= section == "[dependencies]";
            assert!(
                section == "[dev-dependencies]"
                    || !section.contains("dependencies")
                    || section == "[dependencies]",
                "Cargo.toml declares {section}; only [dev-dependencies] may list anything"
            );
            continue;
        }
        if section == "[dependencies]" {
            assert!(
                line.is_empty() || line.starts_with('#'),
                "[dependencies] must stay empty, found: {line}"
            );
        }
    }
    assert!(
        seen_dependencies,
        "Cargo.toml should keep an explicit, empty [dependencies] table"
    );
}
