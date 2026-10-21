coverage: 
	dart run test --concurrency=1 --coverage=./coverage
	dart pub global run coverage:format_coverage --check-ignore --packages=.dart_tool/package_config.json --report-on=lib --lcov -o ./coverage/lcov.info -i ./coverage
	genhtml -o ./coverage/report ./coverage/lcov.info
	open ./coverage/report/index.html

test: 
	dart run test --concurrency=1
