# Сборка и подпись HiDnet

## Что можно проверить сейчас

Swift-пакет не зависит от UIKit или Network Extension. Его тесты проверяют
совместимость импорта с форматом Android, значения по умолчанию, секреты в
конфигурации ядра и отказ при некорректных/неподдерживаемых настройках.
Go-тесты проверяют границы пакетов, обратный канал, таймауты, остановку,
отбрасывание IPv6 и разделение системного VPN и состояния транспорта.

Полная iOS-сборка выполняется только на macOS с Xcode. Симулятор подходит для
интерфейса; реальный VPN проверяется на iPhone.

## Xcode

1. Установите Go 1.26.6 из официального дистрибутива и Xcode с iOS SDK.
2. Убедитесь, что `xcode-select -p` указывает на полный Xcode. Откройте Xcode
   один раз, чтобы завершить установку компонентов и принять условия.
3. Из корня репозитория выполните:

   ```bash
   brew install xcodegen
   bash scripts/check.sh
   bash scripts/build-core.sh
   xcodegen generate
   ```

4. Откройте `HiDnet.xcodeproj`. Выберите Team и уникальное значение
   `HIDNET_BUNDLE_PREFIX`, например `com.yourname.hidnet`, на уровне проекта.
   Настройка применяется одновременно к приложению, расширению и группе Keychain.
5. Убедитесь, что у обоих targets включены **Network Extensions → Packet Tunnel**
   и **Keychain Sharing**. Группа должна совпадать: `TEAM_PREFIX` + выбранный
   prefix + `.shared`. Не заменяйте `AppIdentifierPrefix` вручную на произвольный
   Team ID: они могут отличаться у существующих аккаунтов.
6. Для iPhone используйте схему `HiDnet` и подходящий provisioning profile для
   каждого target. Профили и сертификаты должны принадлежать вашему аккаунту.

В архив попадают приложение и встроенное расширение. Сертификат только для
основного приложения не заменяет provisioning profile расширения.

`project.yml` является источником настроек. Сгенерированные `.xcodeproj`, plist,
entitlements, бинарные библиотеки и архивы исключены из Git. Перед повторной
генерацией перенесите постоянные настройки проекта обратно в YAML.

## GitHub Actions

Workflow использует `macos-15`, Go из `engine/go.mod` и XcodeGen. Права ограничены
чтением содержимого репозитория. Он не загружает приложение в App Store Connect,
не создаёт релиз и не использует сертификаты разработчика. Сборка с
`CODE_SIGNING_ALLOWED=NO` проверяет компиляцию. Затем `scripts/package-ipa.py`
упаковывает приложение и расширение в `HiDnet.ipa`. На копию приложения ставится
локальная ad-hoc подпись, чтобы сохранить запрашиваемые entitlements для
переподписи. Она не выдаёт разрешения Apple и не делает IPA устанавливаемым.

Артефакт `HiDnet-IPA` предназначен для переподписи, например SideStore.
[Порядок скачивания и ограничения](SIDELOADING.md). Реальная установка требует
профиля с разрешением на Packet Tunnel для приложения и расширения.

Workflow начнёт работать после отправки файлов в GitHub. Создание workflow
локально не является его запуском. Первый успешный результат Xcode ещё нужно
получить; в Linux он не проверен.

Путь через TestFlight требует Apple Developer Program и отдельной настройки
подписанной облачной сборки. SideStore выполняет подпись на устройстве, однако
также ограничен разрешениями учётной записи. Бесплатный аккаунт не становится
аккаунтом с Network Extensions из-за упаковки в IPA. Секреты вводятся через
защищённые настройки CI или доверенное приложение подписи, не в чат и не в исходники.

## Сеть и воспроизводимость

Go использует `go.sum` и стандартную проверку сумм. Не устанавливайте
`GOSUMDB=off`, `GOINSECURE` или флаги отключения TLS. Публичный Go proxy может
перенаправлять крупные архивы на `storage.googleapis.com`; этот домен нужен при
ограниченном доступе в интернет. Альтернатива для GitHub-модулей — стандартный
`GOPROXY=direct` с сохранением проверки сумм. Не заменяйте версии библиотек
ради обхода ошибки сети.

В исходной облачной среде установлены проверенные Go 1.26.6 и Swift 6.2.3 в
`/workspace/.tools`. Они не являются частью Git-репозитория. Swift-дистрибутив
проверен подписью Swift 6.x Release Signing Key, Go — SHA-256 из официального
списка релизов. Для Linux с недоступным домашним каталогом задайте пути к кэшам:

```bash
export PATH="/workspace/.tools/go/bin:/workspace/.tools/swift-6.2.3-RELEASE-debian12/usr/bin:$PATH"
export GOPATH=/workspace/.tools/gopath
export GOMODCACHE=/workspace/.cache/go-mod
export GOCACHE=/workspace/.cache/go-build
export CLANG_MODULE_CACHE_PATH=/workspace/.cache/clang
export SWIFTPM_MODULECACHE_OVERRIDE=/workspace/.cache/swift-module
swift test --package-path Packages/HiDnetCore \
  --cache-path /workspace/.cache/swiftpm \
  --config-path /workspace/.cache/swiftpm-config \
  --security-path /workspace/.cache/swiftpm-security
```
