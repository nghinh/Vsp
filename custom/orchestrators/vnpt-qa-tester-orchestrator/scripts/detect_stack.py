#!/usr/bin/env python3
"""Detect likely project stack and testing tools.

Usage:
  python scripts/detect_stack.py /path/to/project
"""
from __future__ import annotations
import json
import sys
from pathlib import Path


def exists_any(root: Path, names: list[str]) -> bool:
    for name in names:
        if '*' in name:
            if list(root.rglob(name)):
                return True
        elif (root / name).exists():
            return True
    return False


def detect(root: Path) -> dict:
    result = {"root": str(root), "stacks": [], "recommended_tools": {}}

    # === TypeScript/JavaScript ===
    if exists_any(root, ["package.json"]):
        result["stacks"].append("typescript/javascript")
        pkg = (root / "package.json").read_text(encoding="utf-8", errors="ignore") if (root / "package.json").exists() else ""
        result["recommended_tools"]["unit"] = "vitest" if "vitest" in pkg else "jest_or_vitest"
        result["recommended_tools"]["property"] = "fast-check"
        result["recommended_tools"]["e2e"] = "playwright"
        result["recommended_tools"]["mutation"] = "stryker"
        result["recommended_tools"]["api_fuzz"] = "schemathesis"

    # === Python ===
    if exists_any(root, ["pyproject.toml", "requirements.txt", "setup.py"]):
        result["stacks"].append("python")
        result["recommended_tools"]["unit_python"] = "pytest"
        result["recommended_tools"]["property_python"] = "hypothesis"
        result["recommended_tools"]["api_fuzz_python"] = "schemathesis"
        result["recommended_tools"]["mutation_python"] = "mutmut_or_cosmic_ray"

    # === Java ===
    if exists_any(root, ["pom.xml", "build.gradle", "build.gradle.kts"]):
        result["stacks"].append("java")
        result["recommended_tools"]["unit_java"] = "junit"
        result["recommended_tools"]["mutation_java"] = "pit"
        result["recommended_tools"]["api_test_java"] = "rest_assured"

    # === .NET ===
    if exists_any(root, ["*.csproj", "*.sln"]):
        result["stacks"].append("dotnet")
        result["recommended_tools"]["unit_dotnet"] = "xunit_or_nunit"
        result["recommended_tools"]["mutation_dotnet"] = "stryker-dotnet"

    # === Go (NEW) ===
    if exists_any(root, ["go.mod", "go.sum", "Gopkg.toml", "Gopkg.lock"]):
        result["stacks"].append("go")
        result["recommended_tools"]["unit_go"] = "go-test"
        result["recommended_tools"]["property_go"] = "gopter_or_rapid"
        result["recommended_tools"]["api_test_go"] = "resty_or_hrv"
        result["recommended_tools"]["fuzz_go"] = "go-fuzz"
        result["recommended_tools"]["mutation_go"] = None  # No mature mutation tool for Go

    # === Rust (NEW) ===
    if exists_any(root, ["Cargo.toml", "Cargo.lock"]):
        result["stacks"].append("rust")
        result["recommended_tools"]["unit_rust"] = "cargo-test"
        result["recommended_tools"]["property_rust"] = "proptest_or_quickcheck"
        result["recommended_tools"]["api_test_rust"] = "reqwest_or_http_req"
        result["recommended_tools"]["fuzz_rust"] = "cargo-fuzz"
        result["recommended_tools"]["mutation_rust"] = None  # No mature mutation tool for Rust

    # === PHP (NEW) ===
    if exists_any(root, ["composer.json", "composer.lock"]) or list(root.rglob("*.php")):
        result["stacks"].append("php")
        result["recommended_tools"]["unit_php"] = "phpunit_or_pest"
        result["recommended_tools"]["property_php"] = "phpunit_property"
        result["recommended_tools"]["api_test_php"] = "phpunit_or_dusk"
        result["recommended_tools"]["mutation_php"] = "infection"

    # === Ruby (NEW) ===
    if exists_any(root, ["Gemfile", "Gemfile.lock", "Rakefile"]):
        result["stacks"].append("ruby")
        result["recommended_tools"]["unit_ruby"] = "rspec_or_minitest"
        result["recommended_tools"]["property_ruby"] = "rantly_or_quickcheck"
        result["recommended_tools"]["mutation_ruby"] = "mutant"

    # === API Schema Detection ===
    if list(root.rglob("openapi*.yml")) or list(root.rglob("openapi*.yaml")) or list(root.rglob("openapi*.json")):
        result["api_schema"] = True
        result["recommended_tools"]["api_schema_fuzz"] = "schemathesis"
    else:
        result["api_schema"] = False

    # === Framework-specific detection ===
    # Next.js detection
    if exists_any(root, ["next.config.js", "next.config.ts", "next.config.mjs"]):
        result["framework"] = "nextjs"
        result["recommended_tools"]["e2e"] = "playwright"  # Next.js works well with Playwright

    # NestJS detection
    if exists_any(root, ["nest-cli.json", "tsconfig.json"]) and (root / "src").exists():
        package_json = (root / "package.json").read_text(encoding="utf-8", errors="ignore") if (root / "package.json").exists() else ""
        if "nestjs" in package_json.lower() or "@nestjs" in package_json:
            result["framework"] = "nestjs"
            result["recommended_tools"]["e2e"] = "jest_or_supertest"
            result["recommended_tools"]["api_test_nestjs"] = "supertest"

    # React Native detection
    if exists_any(root, ["app.json"]) and exists_any(root, ["package.json"]):
        pkg = (root / "package.json").read_text(encoding="utf-8", errors="ignore") if (root / "package.json").exists() else ""
        if "react-native" in pkg or "expo" in pkg:
            result["framework"] = "react_native"
            result["recommended_tools"]["unit_mobile"] = "jest"
            result["recommended_tools"]["e2e_mobile"] = "detox_or_aws_device_farm"

    # Flutter detection
    if exists_any(root, ["pubspec.yaml", "pubspec.lock"]):
        result["framework"] = "flutter"
        result["recommended_tools"]["unit_flutter"] = "flutter_test"
        result["recommended_tools"]["widget_test_flutter"] = "flutter_test"
        result["recommended_tools"]["integration_test_flutter"] = "integration_test"

    return result


if __name__ == "__main__":
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    print(json.dumps(detect(root), ensure_ascii=False, indent=2))
