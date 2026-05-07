SHELL := /bin/bash

REQUIRED_TOOLS := git brew elixir erl mix podman tofu
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
	if command -v tk >/dev/null 2>&1 || command -v ticket >/dev/null 2>&1; then \
		printf "OK       %s\n" "tk/ticket"; \
	else \
		printf "MISSING  %s\n" "tk (brew tap wedow/tools && brew install ticket)"; \
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
	@command -v tk >/dev/null 2>&1 || command -v ticket >/dev/null 2>&1 || { brew tap wedow/tools && brew install ticket; }
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
	@{ command -v tk >/dev/null && tk help 2>/dev/null | head -n 1; } || { command -v ticket >/dev/null && ticket help 2>/dev/null | head -n 1; } || true
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

check:
	mix compile
	CAPS_MANIFEST_PATH=caps.toml.example mix capabilities.check
	CAPS_MANIFEST_PATH=caps.toml.example mix capabilities.audit
	mix test
	mix capabilities.diffcheck
