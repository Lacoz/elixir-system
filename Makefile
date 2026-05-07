SHELL := /bin/bash

REQUIRED_TOOLS := git brew elixir erl mix podman bd tofu
OPTIONAL_TOOLS := psql vault

.PHONY: doctor install-tools versions setup dev dev-down test check

doctor:
	@echo "Checking required local development tools..."
	@missing=0; \
	for tool in $(REQUIRED_TOOLS); do \
		if command -v $$tool >/dev/null 2>&1; then \
			printf "OK       %s\n" "$$tool"; \
		else \
			printf "MISSING  %s\n" "$$tool"; \
			missing=1; \
		fi; \
	done; \
	if podman compose version >/dev/null 2>&1; then \
		printf "OK       %s\n" "podman compose"; \
	else \
		printf "MISSING  %s\n" "podman compose"; \
		missing=1; \
	fi; \
	echo ""; \
	echo "Checking optional local CLIs..."; \
	for tool in $(OPTIONAL_TOOLS); do \
		if command -v $$tool >/dev/null 2>&1; then \
			printf "OK       %s\n" "$$tool"; \
		else \
			printf "OPTIONAL %s\n" "$$tool"; \
		fi; \
	done; \
	if [ $$missing -ne 0 ]; then \
		echo ""; \
		echo "Some required tools are missing. Run: make install-tools"; \
		exit 1; \
	fi

install-tools:
	@command -v brew >/dev/null 2>&1 || { \
		echo "Homebrew is required. Install it from https://brew.sh"; \
		exit 1; \
	}
	@command -v elixir >/dev/null 2>&1 || brew install elixir
	@command -v podman >/dev/null 2>&1 || brew install podman
	@podman compose version >/dev/null 2>&1 || brew install podman-compose
	@command -v bd >/dev/null 2>&1 || brew install beads
	@command -v tofu >/dev/null 2>&1 || brew install opentofu
	@command -v psql >/dev/null 2>&1 || brew install postgresql@16
	@command -v vault >/dev/null 2>&1 || { \
		brew tap hashicorp/tap; \
		brew install hashicorp/tap/vault; \
	}

versions:
	@elixir --version
	@erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell
	@podman --version
	@podman compose version
	@bd --version
	@tofu version
	@command -v psql >/dev/null 2>&1 && psql --version || true
	@command -v vault >/dev/null 2>&1 && vault version || true

setup: doctor
	mix deps.get
	mix compile

dev:
	podman compose -f infra/local/compose.yml up

dev-down:
	podman compose -f infra/local/compose.yml down -v

test:
	mix test

# mix capabilities.check and credo are added once those tasks/deps exist in this repo.
check:
	mix compile
	mix test
