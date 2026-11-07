#!/usr/bin/env bash
# ==============================================================================
# Скрипт безопасного обновления приложения RatingHelper через xtool
# Сохраняет существующий Bundle ID (org.ratinghelper.susu), данные Keychain,
# настройки UserDefaults и локальные файлы без удаления приложения.
# ==============================================================================

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "========================================================"
echo "🚀 Rating Helper 2.0.0 — Скрипт обновления через xtool"
echo "========================================================"

# 1. Проверка наличия xtool
if ! command -v xtool &> /dev/null; then
    if [ -f "/usr/local/bin/xtool" ]; then
        export PATH="/usr/local/bin:${PATH}"
    elif [ -f "/mnt/c/Users/Иван/xtool" ]; then
        export PATH="/mnt/c/Users/Иван:${PATH}"
    else
        echo "❌ Ошибка: xtool не найден в PATH."
        exit 1
    fi
fi

echo "✅ xtool обнаружен: $(xtool --version 2>&1 | head -n 1)"

# 2. Проверка подключения iPhone с тайм-аутом
echo "📱 Проверка подключения устройства..."
DEVICE_OUTPUT=$(timeout 4 xtool devices 2>&1 || true)
echo "$DEVICE_OUTPUT"

# 3. Сборка проекта
echo "🔨 Сборка проекта для iOS (конфигурация: debug)..."
xtool dev build

APP_PATH="$PROJECT_DIR/xtool/RatingHelper.app"
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Ошибка: Собранное приложение не найдено по пути $APP_PATH"
    exit 1
fi

echo "✅ Сборка успешно завершена: $APP_PATH"

# 4. Проверка сохранения Bundle ID
BUNDLE_ID=$(python3 -c "
import plistlib, sys
try:
    with open('$APP_PATH/Info.plist', 'rb') as f:
        d = plistlib.load(f)
        print(d.get('CFBundleIdentifier', ''))
except Exception as e:
    sys.exit(1)
")

if [ "$BUNDLE_ID" != "org.ratinghelper.susu" ]; then
    echo "❌ Ошибка: Bundle ID изменился ($BUNDLE_ID != org.ratinghelper.susu)!"
    echo "Предотвращена установка для сохранения существующего App ID."
    exit 1
fi

echo "🔒 Bundle ID подтверждён: $BUNDLE_ID (существующий App ID сохранён)"

# 5. Установка поверх существующей версии
if [ -n "$DEVICE_OUTPUT" ] && ! echo "$DEVICE_OUTPUT" | grep -qi "No devices"; then
    echo "📲 Установка обновления поверх существующей версии (без удаления данных)..."
    xtool install "$APP_PATH"
    echo "🎉 Установка успешно завершена! Ваши данные и сессия сохранены."
else
    echo "📦 Приложение собрано и готово к установке."
    echo "Подключите iPhone через USB, привяжите через usbipd (если в WSL) и выполните:"
    echo "   xtool install \"$APP_PATH\""
fi
