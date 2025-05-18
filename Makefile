fmt:
	echo "===> Formatting"
	stylua lua/ --config-path=.stylua.toml

lint:
	echo "===> Linting"
	luacheck lua/ --globals vim

test:
	echo "===> Testing"
	echo "Preparing test server"
	docker compose up -d || \
		(echo "Test image not present, building..." && cd test-server && docker build -t autocomplicate-test-server . && cd .. && docker compose up -d)
	nvim --headless  \
        -c "lua require('plenary.test_harness').test_directory('lua/autocomplicate/test/', {minimal_init = 'scripts/tests/minimal.vim'})"
	docker compose down

clean:
	echo "===> Cleaning"
	rm /tmp/lua_*

pr-ready: fmt lint test
