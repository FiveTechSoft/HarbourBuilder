#!/usr/bin/env python3
"""Compile the actual Windows HTTP function bodies using a small Harbour shim.
This is a Linux AddressSanitizer regression, not a Windows GUI build.
"""
from pathlib import Path
import subprocess, tempfile, re
root = Path(__file__).resolve().parents[1]
source = (root / 'source/cpp/hbbridge.cpp').read_text()
functions = []
for name in ('UI_HTTPGET', 'UI_HTTPPOST'):
    match = re.search(r'HB_FUNC\( '+name+r' \)\s*\{.*?^\}', source, re.S | re.M)
    if not match:
        raise SystemExit('Cannot locate '+name)
    functions.append(match.group())
shim = r'''
#include <cstdio>
#include <cstring>
#include <string>
#define HB_FUNC(name) void name()
static std::string input, output;
static const char * hb_parc(int n) { return n == 1 ? input.c_str() : "body"; }
static void hb_retc(const char * s) { output = s; }
'''
main = r'''
int main() {
  for (size_t n : {0u, 1u, 200u, 255u, 256u, 4096u, 65536u}) {
    input.assign(n, 'A');
    UI_HTTPGET();
    if (output.size() >= 256) return 2;
    UI_HTTPPOST();
    if (output.size() >= 256) return 3;
  }
  puts("PASS: extracted Windows HTTP functions accept long input without buffer overflow");
}
'''
with tempfile.TemporaryDirectory() as work:
    cpp = Path(work)/'http.cpp'; binary = Path(work)/'http'
    cpp.write_text(shim+'\n'.join(functions)+main)
    subprocess.run(['g++','-std=c++11','-fsanitize=address,undefined','-g',str(cpp),'-o',str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
