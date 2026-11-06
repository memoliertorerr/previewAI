# All SwiftPM calls go through here so caches stay inside the repo (.build/).
SWIFTPM_PATHS = --cache-path .build/cache --config-path .build/config --security-path .build/security
SWIFT_FLAGS   = $(SWIFTPM_PATHS) --scratch-path .build
APPSTORE_FLAGS = $(SWIFTPM_PATHS) --scratch-path .build/appstore -Xswiftc -DAPPSTORE
VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)

.PHONY: build test app app-appstore lint verify dist clean

build:
	swift build $(SWIFT_FLAGS)

test:
	swift test $(SWIFT_FLAGS)

app:
	swift build -c release $(SWIFT_FLAGS)
	scripts/bundle.sh "$$(swift build -c release $(SWIFT_FLAGS) --show-bin-path)/PreviewAI" build/PreviewAI.app

# Same sources with Apple Events and CLI providers compiled out (Mac App Store readiness).
app-appstore:
	swift build -c release $(APPSTORE_FLAGS)
	scripts/bundle.sh "$$(swift build -c release $(APPSTORE_FLAGS) --show-bin-path)/PreviewAI" build/appstore/PreviewAI.app

lint:
	@for app in build/PreviewAI.app build/appstore/PreviewAI.app; do \
		plutil -lint "$$app/Contents/Info.plist" || exit 1; \
		test "$$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$$app/Contents/Info.plist")" = "true" || { echo "LSUIElement missing in $$app"; exit 1; }; \
		codesign --verify --deep "$$app" || exit 1; \
	done
	@echo "lint: ok"

verify: build test app app-appstore lint
	@echo "verify: ok"

dist: app
	mkdir -p dist
	rm -f dist/PreviewAI-$(VERSION).zip
	ditto -c -k --keepParent build/PreviewAI.app dist/PreviewAI-$(VERSION).zip
	@echo "dist: dist/PreviewAI-$(VERSION).zip"

clean:
	rm -rf .build build dist
