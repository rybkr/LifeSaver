DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
export DEVELOPER_DIR

.PHONY: build test smoke verify install motion
build:
	xcodebuild -project UnixLife.xcodeproj -scheme UnixLife -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual build

test:
	xcrun swift test --scratch-path build/swift-tests

smoke: build
	xcrun swiftc -parse-as-library -module-cache-path build/ModuleCache.noindex Scripts/SmokeCheck.swift -o build/smoke-check
	build/smoke-check build/Build/Products/Release/UnixLife.saver

verify: build
	xcrun swiftc -parse-as-library -module-cache-path build/ModuleCache.noindex Scripts/VerifyClock.swift -o build/verify-clock
	build/verify-clock build/Build/Products/Release/UnixLife.saver

install: build
	bash Scripts/install.sh

motion:
	mkdir -p build
	xcrun swiftc -parse-as-library -module-cache-path build/ModuleCache.noindex UnixLife/Core/*.swift UnixLife/SaverRenderer.swift Scripts/RenderMotion.swift -o build/render-motion
	build/render-motion
