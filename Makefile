INSTALL_DIR ?= $(HOME)/Applications
APP := dist/AI Usage Bar.app

.PHONY: help check core-check providers-check build run install zip clean

help:
	@printf '%s\n' \
	  'make check            core + provider checks, then package the app' \
	  'make build            package dist/AI Usage Bar.app' \
	  'make run              build and open the app' \
	  'make install          build and copy to $$(INSTALL_DIR) (default ~/Applications)' \
	  'make zip              build dist/AI-Usage-Bar-<version>.zip for a release'

check: core-check providers-check build

core-check:
	swift run UsageCoreCheck

providers-check:
	swift run UsageProvidersCheck

build:
	bash scripts/package_app.sh

run: build
	open "$(APP)"

install: build
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_DIR)/AI Usage Bar.app"
	ditto "$(APP)" "$(INSTALL_DIR)/AI Usage Bar.app"
	@echo "Installed to $(INSTALL_DIR)/AI Usage Bar.app"

zip: build
	bash scripts/zip_app.sh

clean:
	rm -rf dist
