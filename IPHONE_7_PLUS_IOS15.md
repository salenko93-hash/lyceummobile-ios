# LyceumMobile iOS 1.0 — iPhone 7 Plus / iOS 15

## Що змінено

- Deployment target: **iOS 15.0** замість iOS 16.0.
- `NavigationStack` замінено на `NavigationView`.
- Прибрано iOS 16-only `scrollContentBackground`, `LabeledContent`
  та багаторядковий `TextField(..., axis:)`.
- Target залишається iPhone-only (`TARGETED_DEVICE_FAMILY = 1`).
- Bundle ID: `ua.edu.cunl.lyceummobile`.
- Версія застосунку: 1.0, build 2.
- Codemagic `ios-compile` створює `LyceumMobile-unsigned.ipa`,
  придатний для подальшого локального підпису на Windows.

## Збірка в Codemagic

1. Завантажте цей проєкт у ваш **Private** GitHub-репозиторій
   `lyceummobile-ios`.
2. У Codemagic запустіть workflow `ios-compile`.
3. Дочекайтеся `Build successful`.
4. У Artifacts завантажте:
   `build/ios/ipa/LyceumMobile-unsigned.ipa`.

## Встановлення на iPhone 7 Plus з Windows

Unsigned IPA безпосередньо iOS не встановлює. Для локального тестування
його треба підписати вашим Apple ID, наприклад через офіційно завантажений
Sideloadly. Не надсилайте пароль Apple ID у чат.

Загальна послідовність:
1. Підключіть iPhone 7 Plus USB-кабелем і підтвердьте «Довіряти».
2. Переконайтеся, що Windows бачить iPhone через компоненти Apple.
3. Відкрийте Sideloadly та виберіть `LyceumMobile-unsigned.ipa`.
4. Виберіть підключений iPhone і виконайте локальний підпис/встановлення.
5. Якщо iOS попросить довіряти сертифікату розробника, виконайте
   відповідний пункт у Налаштуваннях iPhone.
6. Для безкоштовного Apple ID локальний підпис має обмежений строк
   дії, тому застосунок доведеться періодично підписувати повторно.

## Перевірка сумісності

Локально пройдено:
- `swift test --jobs 2`: 4/4 core-тести;
- `python tools/validate_data.py`: структура 4 розкладів, Info.plist,
  deployment target 15.0, відсутність відомих iOS 16-only API;
- перевірено, що Codemagic пакує unsigned IPA.

Повну компіляцію SwiftUI/iOS SDK треба підтвердити workflow
`ios-compile` на macOS/Codemagic, оскільки Xcode на Windows/Linux
не запускається.
