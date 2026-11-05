"""COROBS is pure: no runtime dependency, and the package imports only the standard library."""

import ast
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_the_project_declares_no_dependencies():
    text = (ROOT / "pyproject.toml").read_text(encoding="utf-8")
    match = re.search(r"^dependencies\s*=\s*\[(.*?)\]", text, re.MULTILINE | re.DOTALL)
    assert match, "pyproject.toml must declare dependencies explicitly"
    assert match.group(1).strip() == "", "the library has no runtime dependencies"


def test_the_package_imports_only_the_standard_library():
    allowed = set(sys.stdlib_module_names) | {"corobs"}
    for path in (ROOT / "src" / "corobs").glob("*.py"):
        for node in ast.walk(ast.parse(path.read_text(encoding="utf-8"))):
            if isinstance(node, ast.Import):
                names = [a.name for a in node.names]
            elif isinstance(node, ast.ImportFrom) and node.level == 0:
                names = [node.module or ""]
            else:
                continue
            for name in names:
                assert name.split(".")[0] in allowed, f"{path.name} imports {name}"
