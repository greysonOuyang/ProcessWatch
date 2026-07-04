.PHONY: doctor check review test build debug universal run clean install install-system dmg release

doctor:
	./doctor.sh
check:
	./scripts/source_check.sh

review:
	./scripts/review_product.sh

test:
	./scripts/test_logic.sh
build:
	./build.sh --release

debug:
	./build.sh --debug

universal:
	./build.sh --release --universal

run:
	./build.sh --clean --run

clean:
	./clean.sh

install:
	./scripts/install_app.sh

install-system:
	./scripts/install_app.sh --system

dmg:
	./scripts/package_dmg.sh --universal

release:
	./scripts/release.sh
