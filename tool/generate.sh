#!/bin/sh
set -e

(cd pkg/wasi && ./generate.sh)
(cd integration_tests && dart run tool/generate.dart)
(cd pkg/test_runner && dart run wasm_tools witgen -i world.wit)
(cd pkg/wasm_tools/example/greeting && dart run wasm_tools witgen -i test.wit)