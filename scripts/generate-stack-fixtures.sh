#!/usr/bin/env bash
# Regenerates Fixtures/stacks/* and Fixtures/expected.json for DevDock detection tests.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STACKS="$ROOT/Fixtures/stacks"
EXPECTED="$ROOT/Fixtures/expected.json"

rm -rf "$STACKS"
mkdir -p "$STACKS"

write() {
  local path="$1"
  shift
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$@" > "$path"
}

pkg() {
  # pkg <dir> <depName> [script=dev] [extraDepsJson]
  local dir="$1" dep="$2"
  local script="${3:-dev}"
  local extra="${4:-}"
  local deps="\"$dep\": \"*\""
  if [[ -n "$extra" ]]; then
    deps="$deps, $extra"
  fi
  write "$STACKS/$dir/package.json" "{
  \"name\": \"fixture-$dir\",
  \"private\": true,
  \"scripts\": { \"$script\": \"echo fixture\" },
  \"dependencies\": { $deps }
}"
}

echo "Generating stack fixtures under $STACKS"

# —— Web ——
write "$STACKS/nextjs/next.config.js" "module.exports = {}"
pkg nextjs next

write "$STACKS/nuxt/nuxt.config.ts" "export default {}"
pkg nuxt nuxt

write "$STACKS/remix/remix.config.js" "module.exports = {}"
pkg remix "@remix-run/react"

write "$STACKS/astro/astro.config.mjs" "export default {}"
pkg astro astro

write "$STACKS/gatsby/gatsby-config.js" "module.exports = {}"
pkg gatsby gatsby

write "$STACKS/angular/angular.json" "{ \"version\": 1, \"projects\": {} }"
pkg angular "@angular/core"

pkg sveltekit "@sveltejs/kit"
write "$STACKS/sveltekit/svelte.config.js" "export default {}"

pkg svelte svelte
write "$STACKS/svelte/svelte.config.js" "export default {}"

pkg solid solid-js
write "$STACKS/solid/vite.config.ts" "export default {}"

write "$STACKS/ember/ember-cli-build.js" "module.exports = function() {}"
pkg ember ember-source

write "$STACKS/vite/vite.config.ts" "export default {}"
pkg vite vite

write "$STACKS/vue/vue.config.js" "module.exports = {}"
pkg vue vue

pkg react react

write "$STACKS/quasar/quasar.config.js" "module.exports = {}"
pkg quasar quasar

# —— Mobile ——
pkg expo expo start
write "$STACKS/expo/app.json" "{ \"expo\": { \"name\": \"fixture-expo\", \"slug\": \"fixture-expo\" } }"

pkg react-native react-native start
write "$STACKS/react-native/metro.config.js" "module.exports = {}"

write "$STACKS/flutter/pubspec.yaml" "name: fixture_flutter
description: DevDock fixture
publish_to: \"none\"
environment:
  sdk: \">=3.0.0 <4.0.0\"
dependencies:
  flutter:
    sdk: flutter"

write "$STACKS/ionic/ionic.config.json" "{ \"name\": \"fixture-ionic\", \"type\": \"react\" }"
pkg ionic "@ionic/react"

# —— Node API ——
write "$STACKS/nestjs/nest-cli.json" "{ \"collection\": \"@nestjs/schematics\" }"
pkg nestjs "@nestjs/core"

pkg express express
pkg fastify fastify
pkg hono hono
pkg koa koa

# —— Other backends ——
write "$STACKS/laravel/artisan" "#!/usr/bin/env php
<?php // DevDock fixture"
write "$STACKS/laravel/composer.json" "{ \"name\": \"fixture/laravel\", \"require\": { \"laravel/framework\": \"*\" } }"

write "$STACKS/symfony/symfony.lock" "{}"
write "$STACKS/symfony/composer.json" "{ \"name\": \"fixture/symfony\", \"require\": { \"symfony/framework-bundle\": \"*\" } }"

write "$STACKS/django/manage.py" "#!/usr/bin/env python3
print(\"fixture\")"

write "$STACKS/flask/app.py" "from flask import Flask
app = Flask(__name__)"
write "$STACKS/flask/requirements.txt" "flask==3.0.0"

write "$STACKS/fastapi/requirements.txt" "fastapi==0.110.0
uvicorn==0.27.0"
write "$STACKS/fastapi/main.py" "from fastapi import FastAPI
app = FastAPI()"

write "$STACKS/rails/Gemfile" "source \"https://rubygems.org\"
gem \"rails\", \"~> 7.0\""

write "$STACKS/phoenix/mix.exs" "defmodule Fixture.MixProject do
  use Mix.Project
  def project, do: [app: :fixture, version: \"0.1.0\", deps: [{:phoenix, \"~> 1.7\"}]]
end"

write "$STACKS/spring/pom.xml" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.devdock</groupId>
  <artifactId>fixture-spring</artifactId>
  <version>0.0.1</version>
  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
      <version>3.2.0</version>
    </dependency>
  </dependencies>
</project>"

write "$STACKS/dotnet/Fixture.csproj" "<Project Sdk=\"Microsoft.NET.Sdk.Web\">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
</Project>"

write "$STACKS/go/go.mod" "module fixture/go

go 1.22"
write "$STACKS/go/main.go" "package main
func main() {}"

write "$STACKS/rust/Cargo.toml" "[package]
name = \"fixture-rust\"
version = \"0.1.0\"
edition = \"2021\""

# —— Desktop ——
pkg electron electron
write "$STACKS/tauri/src-tauri/.gitkeep" ""
write "$STACKS/tauri/Cargo.toml" "[package]
name = \"fixture-tauri\"
version = \"0.1.0\"
edition = \"2021\""
pkg tauri "@tauri-apps/cli"

# expected.json — folder name → Framework.rawValue
python3 - <<'PY'
import json, os
root = os.environ.get("STACKS") or ""
# paths set below
PY

STACKS="$STACKS" EXPECTED="$EXPECTED" python3 <<'PY'
import json, os

expected = {
    "nextjs": {"framework": "Next.js", "port": 3000},
    "nuxt": {"framework": "Nuxt", "port": 3000},
    "remix": {"framework": "Remix", "port": 3000},
    "astro": {"framework": "Astro", "port": 4321},
    "gatsby": {"framework": "Gatsby", "port": 3000},
    "angular": {"framework": "Angular", "port": 3000},
    "sveltekit": {"framework": "SvelteKit", "port": 5173},
    "svelte": {"framework": "Svelte", "port": 5173},
    "solid": {"framework": "Solid", "port": 5173},
    "ember": {"framework": "Ember", "port": 3000},
    "vite": {"framework": "Vite", "port": 5173},
    "vue": {"framework": "Vue", "port": 5173},
    "react": {"framework": "React", "port": 3000},
    "quasar": {"framework": "Quasar", "port": 5173},
    "expo": {"framework": "Expo", "port": 8081},
    "react-native": {"framework": "React Native", "port": 8081},
    "flutter": {"framework": "Flutter", "port": 8080},
    "ionic": {"framework": "Ionic", "port": 8081},
    "nestjs": {"framework": "NestJS", "port": 3000},
    "express": {"framework": "Express", "port": 3000},
    "fastify": {"framework": "Fastify", "port": 3000},
    "hono": {"framework": "Hono", "port": 3000},
    "koa": {"framework": "Koa", "port": 3000},
    "laravel": {"framework": "Laravel", "port": 8000},
    "symfony": {"framework": "Symfony", "port": 8000},
    "django": {"framework": "Django", "port": 8000},
    "flask": {"framework": "Flask", "port": 8000},
    "fastapi": {"framework": "FastAPI", "port": 8000},
    "rails": {"framework": "Rails", "port": 3000},
    "phoenix": {"framework": "Phoenix", "port": 4000},
    "spring": {"framework": "Spring Boot", "port": 8080},
    "dotnet": {"framework": ".NET", "port": 5000},
    "go": {"framework": "Go", "port": 8080},
    "rust": {"framework": "Rust", "port": 8080},
    "electron": {"framework": "Electron", "port": None},
    "tauri": {"framework": "Tauri", "port": None},
}

stacks = os.environ["STACKS"]
missing = [k for k in expected if not os.path.isdir(os.path.join(stacks, k))]
extra = sorted(set(os.listdir(stacks)) - set(expected))
if missing:
    raise SystemExit(f"Missing fixture dirs: {missing}")
if extra:
    raise SystemExit(f"Unexpected fixture dirs: {extra}")

payload = {
    "description": "Expected FrameworkDetector results for Fixtures/stacks",
    "stacksRoot": "Fixtures/stacks",
    "projects": {
        name: {
            "framework": meta["framework"],
            "port": meta["port"],
        }
        for name, meta in sorted(expected.items())
    },
}
with open(os.environ["EXPECTED"], "w") as f:
    json.dump(payload, f, indent=2)
    f.write("\n")
print(f"Wrote {os.environ['EXPECTED']} ({len(expected)} stacks)")
PY

echo "Done. $(find "$STACKS" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ') fixture projects."
