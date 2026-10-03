#!/usr/bin/env python3
"""Gate xcresulttool test tree + summary against exact intended XCTest paths."""
import argparse
import json
from pathlib import Path


def _name(value):
    if not isinstance(value, str):
        return ""
    return value.removesuffix("()").removesuffix(".xctest")


def validate_results(summary, tests, expected):
    errors = []
    if not expected or len(set(expected)) != len(expected):
        return ["expected test paths must be nonempty and unique"]
    if not isinstance(summary, dict) or not isinstance(tests, dict):
        return ["xcresult summary and test tree must be objects"]
    for key in ("totalTestCount", "passedTests", "failedTests"):
        value = summary.get(key)
        if type(value) is not int or value < 0:
            errors.append(f"summary {key} must be a nonnegative integer")
    if errors:
        return errors
    if summary["totalTestCount"] < len(expected) or summary["passedTests"] < len(expected):
        errors.append("zero or insufficient executed/passed tests")
    if summary["failedTests"] != 0 or summary.get("result") != "Passed":
        errors.append("the overall test action must be Passed with zero failures")
    skipped = summary.get("skippedTests", 0)
    if type(skipped) is not int or skipped < 0:
        errors.append("summary skippedTests must be a nonnegative integer")
    elif summary["passedTests"] + summary["failedTests"] + skipped != summary["totalTestCount"]:
        errors.append("summary passed/failed/skipped counts must equal totalTestCount")

    paths = []

    def visit(node, parents):
        if not isinstance(node, dict):
            return
        kind = str(node.get("nodeType", "")).lower().replace(" ", "")
        path = [*parents, (kind, _name(node.get("name")))]
        if node.get("nodeType") == "Test Case":
            paths.append((path, node.get("result")))
        children = node.get("children", [])
        if isinstance(children, list):
            for child in children:
                visit(child, path)

    nodes = tests.get("testNodes")
    if not isinstance(nodes, list):
        return [*errors, "testNodes must be a list"]
    for node in nodes:
        visit(node, [])
    for identifier in expected:
        names = [_name(part) for part in identifier.split("/")]
        if len(names) != 3 or any(not part for part in names):
            errors.append(f"expected path must be bundle/class/method: {identifier}")
            continue
        wanted = list(zip(("unittestbundle", "testsuite", "testcase"), names))
        matches = [result for path, result in paths if path[-3:] == wanted]
        if matches != ["Passed"]:
            errors.append(f"expected exactly one Passed test case: {identifier}; observed={matches}")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary-json", required=True, type=Path)
    parser.add_argument("--tests-json", required=True, type=Path)
    parser.add_argument("--expected", required=True, action="append")
    args = parser.parse_args()
    try:
        summary = json.loads(args.summary_json.read_text())
        tests = json.loads(args.tests_json.read_text())
    except (OSError, ValueError) as error:
        print(f"FAIL_NATIVE_TEST_EVIDENCE: {error}")
        return 1
    errors = validate_results(summary, tests, args.expected)
    if errors:
        for error in errors:
            print(f"FAIL_NATIVE_TEST_EVIDENCE: {error}")
        return 1
    print(f"PASS_NATIVE_TEST_EVIDENCE: total={summary['totalTestCount']} "
          f"passed={summary['passedTests']} intended={len(args.expected)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
