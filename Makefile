PI_HOST ?=

.PHONY: up down init init-central init-local migrate-central migrate-local validate-central validate-local seed deploy-local check clean help

up:
	docker compose up -d

down:
	docker compose down

init:
	./scripts/init-db.sh all

init-central:
	./scripts/init-db.sh central

init-local:
	./scripts/init-db.sh local

migrate-central:
	./scripts/migrate-central.sh migrate

migrate-local:
	./scripts/migrate-local.sh migrate

validate-central:
	./scripts/migrate-central.sh validate

validate-local:
	./scripts/migrate-local.sh validate

seed:
	./scripts/seed-central.sh

deploy-local:
	./scripts/deploy-local.sh $(PI_HOST)

check:
	shellcheck -x --severity=warning scripts/*.sh scripts/lib/*.sh
	@echo "==> Checking migration naming conventions ..."
	@fail=0; \
	for f in $$(find central/sql local/sql -maxdepth 1 -type f -name '*.sql' 2>/dev/null); do \
		base=$$(basename "$$f"); \
		if ! echo "$$base" | grep -qE '^V[0-9]+__[a-z_]+\.sql$$'; then \
			echo "  [error] $$f does not match V<N>__<description>.sql"; \
			fail=1; \
		fi; \
	done; \
	if [ "$$fail" -eq 0 ]; then echo "  All migration files follow naming conventions."; fi; \
	exit "$$fail"

clean:
	rm -rf local/data/nomon_local

help:
	@echo "Available targets:"
	@echo "  up               - Start ArcadeDB container (docker compose up -d)"
	@echo "  down             - Stop ArcadeDB container (docker compose down)"
	@echo "  init             - Create databases and run all migrations"
	@echo "  init-central     - Create and migrate central database only"
	@echo "  init-local       - Create and migrate local database only"
	@echo "  migrate-central  - Run central migrations"
	@echo "  migrate-local    - Run local migrations"
	@echo "  validate-central - Validate central migration checksums"
	@echo "  validate-local   - Validate local migration checksums"
	@echo "  seed             - Seed central database with test data"
	@echo "  deploy-local     - Deploy local schema to Pi (PI_HOST=user@host)"
	@echo "  check            - Run shellcheck and migration naming validation"
	@echo "  clean            - Remove local embedded database data"
	@echo "  help             - Show this help"
