#!/usr/bin/env python3
"""Rebuild closed QA bytes from the app-only education course and policy.

The legacy filename is kept for callers; it no longer reads or asserts a fresh
five-app ops catalog. This does not produce media or a release trust root.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path

import build_education_source_projection as education
import check_v2l_source_projection as source

APP = Path(__file__).resolve().parents[1]
OUTPUT = APP / education.OUTPUTS['qa']
OUTPUT_SHA = '469b187a110db399d2b6a2967d4084efb7a7acd8aa6394fb8486393907a1f5f2'


def expected_bytes() -> bytes:
    root_fd = os.open(APP, source.DIR_FLAGS)
    try:
        raw = {key: source.read_from_root(root_fd, source.INPUTS[key], source.LIMITS[key])
               for key in ('course', 'policy')}
    finally:
        os.close(root_fd)
    result = education.expected_files(raw['course'], raw['policy'])['qa']
    source.require(source.digest(result) == OUTPUT_SHA, 'QA_OUTPUT_SHA_DRIFT')
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--write', action='store_true')
    mode.add_argument('--check', action='store_true')
    args = parser.parse_args()
    raw = expected_bytes()
    if args.write:
        source.require(not OUTPUT.exists(), 'VERSIONED_OUTPUT_EXISTS_USE_CHECK')
        OUTPUT.write_bytes(raw)
    else:
        source.require(OUTPUT.is_file() and not OUTPUT.is_symlink() and
                       OUTPUT.read_bytes() == raw, 'QA_OUTPUT_DRIFT')
    print('PASS_OSTINATO_APP_ONLY_EDUCATION_QA_60_420_RELEASE_CLOSED')


if __name__ == '__main__':
    main()
