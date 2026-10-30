#!/usr/bin/env python3
"""Use measured assembly offsets, never ideal constants, for callback checks.
UI and breakpoint lookup are stubs; this is not native GUI navigation.
"""
import pathlib,runpy
runpy.run_path(str(pathlib.Path(__file__).with_name('test_debug_offsets.py')),run_name='__main__')
