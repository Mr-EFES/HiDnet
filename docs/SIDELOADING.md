# IPA через GitHub Actions и SideStore

Для сборки собственный Mac не нужен: workflow использует macOS на GitHub.
Исходники и workflow опубликованы в репозитории GitHub; первая macOS-сборка
прошла успешно. Сборку своей ветки можно запустить вручную.

## Получить IPA на iPhone

1. В Safari откройте репозиторий → **Actions → iOS development build → Run workflow**.
   Выберите ветку с исходниками HiDnet и нажмите **Run workflow**.
2. Дождитесь завершения шага **Upload IPA**. В разделе **Artifacts** скачайте
   **HiDnet-IPA**. Для скачивания артефактов может потребоваться вход в GitHub.
3. Откройте скачанный ZIP в приложении **Файлы**. Внутри находятся
   **HiDnet.ipa** и **HiDnet.ipa.sha256**.
4. Если SideStore уже установлен и настроен: **My Apps → + → HiDnet.ipa**.
   Сохраните расширение **HiDnetTunnel** при выборе расширений. Его удаление
   лишит приложение возможности создавать VPN.

Для опубликованного тега файл `HiDnet.ipa` также доступен непосредственно в
**Releases → Assets**, без ZIP-обёртки GitHub Actions. Архив соответствующих
исходников `HiDnet-source.tar.gz` можно скачать там же.

Если SideStore ещё не установлен, сначала выполните его официальный процесс
установки и настройки pairing/VPN. Наличие IPA не устанавливает сам SideStore
и не создаёт pairing-файл.

## Что именно собирается

`scripts/package-ipa.py --ad-hoc-sign` принимает Xcode archive для iPhone,
проверяет наличие приложения и Packet Tunnel extension и создаёт:

```text
HiDnet.ipa
└── Payload/
    └── HiDnet.app/
        ├── HiDnet
        ├── Info.plist
        └── PlugIns/
            └── HiDnetTunnel.appex/
```

Локальная ad-hoc подпись сохраняет в бинарниках запросы Network Extension и
Keychain Sharing, чтобы переподписывающая программа могла их прочитать.
Это не подпись Apple Developer и не provisioning profile. На GitHub не нужны
Apple ID, пароль или сертификат для создания этого артефакта.

При переподписи SideStore может изменить bundle identifiers. HiDnet определяет
идентификатор расширения по встроенному bundle, а не по старому значению в plist.
Запросы Keychain используют группу, реально предоставленную подписью по умолчанию.
Подписывающая программа должна сохранить одну и ту же общую группу Keychain
первой группой для приложения и расширения; иначе расширение не сможет прочитать
сохранённый профиль. Переподпись на реальном устройстве ещё не проверена.

## Ограничение для VPN

SideStore подписывает приложения с разрешениями вашей Apple Team. Он не
предоставляет отсутствующие capabilities. Для HiDnet нужен entitlement:

```text
com.apple.developer.networking.networkextension = [packet-tunnel-provider]
```

Бесплатный Personal Team не предоставляет нужную возможность Network Extensions.
Поэтому IPA можно собрать, но установка/работа VPN через бесплатный Apple ID
не гарантируется: подпись может быть отклонена или профиль лишится entitlement.
Удаление entitlement ради успешной установки не даст работающий VPN.
Для поддерживаемой подписи VPN требуется подходящая команда Apple Developer и
provisioning profiles с этим разрешением для обоих targets.

В [README SideStore](https://github.com/SideStore/SideStore#em-proxy) описано,
почему сам SideStore использует отдельное App Store-приложение LocalDevVPN
с дополнительными entitlements. Наличие у SideStore собственного локального
VPN не предоставляет этот доступ другим устанавливаемым приложениям.

Перед обновлением/переподписью через SideStore отключите HiDnet и включите
локальный VPN, требуемый вашей версией SideStore: подключения могут конфликтовать.

Компиляция iOS, упаковка IPA и проверка ad-hoc подписи прошли в GitHub Actions
на macOS. Переподпись SideStore и реальный туннель на iPhone ещё не проверены.
