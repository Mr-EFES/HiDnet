# HiDnet

Нативный VPN-клиент OpenFlux для iPhone: SwiftUI, Network Extension и Go-ядро
из `wlruscfd/openflux-server`. Минимальная версия — iOS 16.

**Предварительный релиз:** [v0.1.0-alpha.1](https://github.com/Mr-EFES/HiDnet/releases/tag/v0.1.0-alpha.1)
· [Скачать HiDnet.ipa](https://github.com/Mr-EFES/HiDnet/releases/download/v0.1.0-alpha.1/HiDnet.ipa).
Для установки нужна переподпись; для VPN — разрешение Apple на Network Extensions.

Это первая версия для разработки. Подготовлены исходники приложения и настоящего
VPN-расширения. [Сборка Xcode для iPhone и симулятора прошла на macOS](https://github.com/Mr-EFES/HiDnet/actions/runs/42392315098).
Подключение к серверу на iPhone, переподпись и работа интерфейса на устройстве
ещё не проверены.

## Что реализовано

- Создание, выбор, редактирование и удаление профилей.
- Импорт `openflux://import?data=<base64url-json>` из OpenFlux Android 0.0.8,
  в том числе QR-кодом. Импорт требует просмотра и сохранения; VPN автоматически
  не запускается.
- Ручные профили и профили с ключом. Встроенная в ссылку конфигурация используется
  без сетевой проверки ключа при каждом подключении. Для неразрешённого ключа
  есть явная кнопка проверки через `POST /v1/resolve` по HTTPS.
- Профили и секреты в общем Keychain приложения и расширения. В настройках
  системного VPN хранится только идентификатор профиля.
- Запуск/остановка VPN, состояние канала и счётчики из Go-ядра.
- Захват IPv4, DNS и IPv6. IPv6 отбрасывается, поскольку его нет в выбранном
  пути обработки. При смене сети можно инициировать переподключение.

Принимаются транспорты `yandex`, `volga`, `max`, `yandex_multistream`, `mailru`,
`boards`, `mts`, `telemost`, `cupsonline`. Это перечень интеграций ядра,
а не результаты испытаний каждого транспорта на iOS.

## Сборка без собственного Mac

В репозитории есть [GitHub Actions workflow](.github/workflows/ios.yml) с macOS:
он запускает тесты, собирает Go-библиотеку для iPhone и симуляторов, генерирует
проект Xcode и компилирует приложение вместе с VPN-расширением.

Откройте **Actions → iOS development build**.
Сборку также можно запустить вручную кнопкой **Run workflow**. Артефакт
`HiDnet-unsigned-development-build` содержит неподписанный архив и приложение
для симулятора. Он не устанавливается на iPhone.

Отдельный артефакт **`HiDnet-IPA`** содержит `HiDnet.ipa` и его SHA-256 для
переподписи через SideStore, а также `HiDnet-source.tar.gz` с исходниками и
Go-зависимостями. Эти артефакты сохраняются при ручном запуске и сборке тега.
IPA сохраняет VPN-расширение. Инструкция по скачиванию
на iPhone и ограничения бесплатной подписи: [установка через SideStore](docs/SIDELOADING.md).

При отправке тега `v…` после успешной сборки workflow создаёт предварительный
GitHub Release с IPA, исходниками, контрольными суммами и лицензиями.

Для стандартной установки через TestFlight с облачной сборкой нужен Apple
Developer Program, настройка подписи обоих targets и App Store Connect.
Для обычных приложений SideStore поддерживает переподпись бесплатным Apple ID,
но это не даёт приложению право на Network Extension. Для действующего VPN
нужен provisioning profile с `packet-tunnel-provider`. Если появится Mac, можно отдельно исследовать
возможность подписи через Personal Team; доступность VPN entitlement нельзя
считать гарантированной. Пароли, сертификаты и ключи не добавляйте в Git.

Подробнее: [сборка и подпись](docs/BUILDING.md), [проверка на iPhone](docs/DEVICE_TESTING.md).

## Локальная разработка на macOS

Нужны полный Xcode с iOS SDK, Go **1.26.6** и XcodeGen **2.42+**.
Используйте существующий checkout; отдельный Git worktree не нужен.

```bash
brew install xcodegen
bash scripts/check.sh
bash scripts/build-core.sh
xcodegen generate
open HiDnet.xcodeproj
```

В Xcode выберите собственную Team и уникальный `HIDNET_BUNDLE_PREFIX` для обоих
targets. Настройки подписи и capabilities описаны в инструкции по сборке.

## Проверки без macOS

```bash
swift test --package-path Packages/HiDnetCore
cd engine
go mod verify
go test -mod=readonly -race -ldflags=-checklinkname=0 ./...
```

Сетевые проверки с реальным OpenFlux-сервером в эти тесты не входят.

## Структура

| Путь | Назначение |
| --- | --- |
| `App/` | Интерфейс, сканер QR, выбор профиля, управление VPN |
| `Shared/` | Общее защищённое хранилище |
| `Tunnel/` | `NEPacketTunnelProvider` и обмен IP-пакетами |
| `Packages/HiDnetCore/` | Модели и проверка формата импорта, тестируемые на Linux |
| `engine/` | C API и адаптер Android-совместимого Go-модуля |
| `project.yml` | Источник проекта Xcode и entitlements для XcodeGen |

## Ограничения первой версии

Пока нет прохождения CAPTCHA, разделения по приложениям/сайтам, балансировки,
автоматического запуска VPN по требованию системы и подтверждённой поддержки
UDP/QUIC. Состояние «VPN подключён» не является проверкой доступа в интернет.
Память расширения, восстановление Wi-Fi/LTE и маршрутизация требуют проверки
на настоящем iPhone. [Зафиксированные версии ядра](engine/UPSTREAM.md).

HiDnet распространяется по **GNU GPLv3** для совместимости с Go-ядром OpenFlux.
См. [LICENSE](LICENSE) и [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
Исходники зависимостей с их лицензиями и исходники стандартной библиотеки Go
входят в архив `HiDnet-source.tar.gz`, публикуемый вместе с IPA.
