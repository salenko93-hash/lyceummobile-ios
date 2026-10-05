# Як з Windows установити LyceumMobile на iPhone 7 Plus

## 1. Завантажити код

Створіть окремий **Private** репозиторій `lyceummobile-ios`
(не використовуйте публічний `lyceumtv-updates`, оскільки
в архіві є службова інформація з розкладів укриття).

У PowerShell у розпакованій папці:

```powershell
winget install --id Git.Git -e
# Закрити й знову відкрити PowerShell після встановлення.
git init
git add .
git commit -m "LyceumMobile iOS 1.0"
git branch -M main
git remote add origin https://github.com/ВАШ_ЛОГІН/lyceummobile-ios.git
git push -u origin main
```

Якщо Git запитає ім'я/email, установіть їх через `git config --global
user.name "Ім'я"` і `git config --global user.email "email@example.com"`.
Вхід для push виконайте через Git Credential Manager (браузер).

## 2. Безкоштовна технічна перевірка без Apple-підпису

1. Зареєструйтеся на https://codemagic.io та підключіть GitHub.
2. Додайте застосунок із **Private** репозиторію.
3. Виберіть `codemagic.yaml` у корені і workflow **ios-compile**.
4. Дочекайтеся green build. Якщо є помилка компіляції, збережіть
   build log: `xcodebuild` у Windows локально запустити не можна.
5. Ця збірка підтверджує можливість компіляції на macOS, **але
   непідписаний застосунок не можна встановити на iPhone**.

## 3. Локальний підпис з Windows або TestFlight

Для локального тестового встановлення `LyceumMobile-unsigned.ipa`
можна підписати власним Apple ID через Sideloadly. Для TestFlight і
App Store потрібна оплачувана Apple Developer Program, App ID та
відповідний цифровий підпис.

1. У https://developer.apple.com/account/
   зареєструйте App ID із Bundle ID `ua.edu.cunl.lyceummobile`.
   Якщо ідентифікатор недоступний, змініть його в обох файлах:
   `LyceumMobile.xcodeproj/project.pbxproj` та `codemagic.yaml`.
2. У https://appstoreconnect.apple.com створіть застосунок
   із тим самим Bundle ID, а також окремий App Store Connect API key.
3. У Codemagic Team settings → Integrations підключіть
   цей ключ під точною назвою **LyceumMobile_AppStore**.
4. Налаштуйте сертифікат Apple Distribution і App Store
   provisioning profile (Codemagic дозволяє це зробити через API).
5. Запустіть workflow **ios-testflight**. Він використовує
   `xcode-project use-profiles` і збирає підписаний `.ipa`.
6. Налаштуйте в Codemagic публікацію до App Store Connect або
   завантажте отриману підписану збірку встановленим засобом;
   після обробки запросіть себе до TestFlight.
7. На iPhone встановіть застосунок TestFlight та ввійдіть
   в Apple Account, запрошений на тестування.

Документація:
https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/
https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/

## 4. Перше налаштування застосунку

- API-токен alerts.in.ua введіть **на iPhone** у налаштуваннях.
  Він зберігатиметься в Keychain цього iPhone, без зберігання в GitHub.
- Google Apps Script URL — ваш чинний `/exec` для оголошень.
  Повторно створювати Google Таблицю або скрипт не потрібно.
- GitHub Manifest URL — той самий `content_manifest.json`,
  що використовується Android TV, **лише якщо його дозволено
  віддавати без автентифікації**.
- Натисніть «Синхронізувати всі дані» за умови, що тривоги немає
  та alerts.in.ua щойно успішно перевірений.

**Не відключайте офіційні застосунки екстреного сповіщення.**
LyceumMobile перевіряє стан тривоги тільки у відкритому стані,
а метроном мовчить у фоновому режимі й коли спрацьовує mute switch.
