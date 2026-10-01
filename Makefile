DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
export DEVELOPER_DIR

.PHONY: build test smoke verify install motion benchmark
build:
	xcodebuild -project LifeSaver.xcodeproj -scheme LifeSaver -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual build

test:
	xcrun swift test -c release --scratch-path build/swift-tests

smoke: build
	xcrun swiftc -O -parse-as-library -module-cache-path build/ModuleCache.noindex Scripts/SmokeCheck.swift -o build/smoke-check
	build/smoke-check build/Build/Products/Release/LifeSaver.saver

verify: build
	xcrun swiftc -O -parse-as-library -module-cache-path build/ModuleCache.noindex Scripts/VerifyMatch.swift -o build/verify-match
	build/verify-match build/Build/Products/Release/LifeSaver.saver

install: build
	bash Scripts/install.sh

motion:
	mkdir -p build
	xcrun swiftc -O -parse-as-library -module-cache-path build/ModuleCache.noindex LifeSaver/Core/*.swift LifeSaver/SaverRenderer.swift Scripts/RenderMotion.swift -o build/render-motion
	build/render-motion

benchmark:
	mkdir -p build
	xcrun swiftc -O -parse-as-library -module-cache-path build/ModuleCache.noindex LifeSaver/Core/*.swift Scripts/Benchmark.swift -o build/benchmark
	build/benchmark

.PHONY: runtime-check
runtime-check:
	mkdir -p build
	xcrun swiftc -O -parse-as-library -module-cache-path build/ModuleCache.noindex LifeSaver/Core/*.swift LifeSaver/SimulationSession.swift Scripts/VerifyRuntime.swift -o build/verify-runtime
	build/verify-runtime
