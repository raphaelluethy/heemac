APP := build/Heemac.app
INSTALL_DIR := /Applications
# Signing with a stable identity keeps the Accessibility grant across rebuilds.
SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning | grep -m1 'Apple Development' | awk '{print $$2}')

.PHONY: build app check zip icon install run clean

build:
	swift build -c release

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp .build/release/Heemac $(APP)/Contents/MacOS/Heemac
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	cp Resources/AppIcon.icns LICENSE THIRD_PARTY_NOTICES.md $(APP)/Contents/Resources/
	codesign --force --options runtime --sign "$(if $(SIGN_IDENTITY),$(SIGN_IDENTITY),-)" $(APP)

check: app
	swift test
	plutil -lint $(APP)/Contents/Info.plist
	codesign --verify --strict $(APP)

zip: check
	rm -f build/Heemac.zip
	ditto -c -k --keepParent $(APP) build/Heemac.zip

icon:
	swift scripts/make-icon.swift .
	iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns

install: app
	-pkill -x Heemac
	rm -rf $(INSTALL_DIR)/Heemac.app
	cp -R $(APP) $(INSTALL_DIR)/Heemac.app
	open $(INSTALL_DIR)/Heemac.app

run: app
	-pkill -x Heemac
	open $(APP)

clean:
	rm -rf .build build
