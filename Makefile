.PHONY: build debug run dmg install clean

build:
	./scripts/build_app.sh --release

debug:
	./scripts/build_app.sh --debug

run:
	./scripts/build_app.sh --debug --run

dmg:
	./scripts/package_dmg.sh --release

install:
	./scripts/install_app.sh --release

clean:
	./scripts/clean.sh
