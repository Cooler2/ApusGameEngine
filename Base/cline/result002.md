# Result: Task 002 — Move basic platform primitives from CrossPlatform to Core

## Status: DONE

## What was done
- Добавлены объявления и реализации 6 функций из `Apus.CrossPlatform.pas` в `Apus.Core.pas`:
  1. `Sleep(time:integer)`
  2. `GetTickCount:cardinal`
  3. `GetCurrentThreadID:TThreadID`
  4. `IsDebuggerPresent:boolean`
  5. `GetLastErrorCode:cardinal`
  6. `GetLastErrorDesc:string`
- Добавлена секция `implementation uses` в `Apus.Core.pas` с необходимыми системными модулями для Windows, UNIX, iOS и Linux
- Добавлены объявления типов `TThreadID` с платформозависимыми определениями
- Удалены объявления и реализации перемещённых функций из `Apus.CrossPlatform.pas`
- Добавлен `Apus.Core` в секцию `uses` в `Apus.CrossPlatform.pas`
- Функция `MemoryBarrier` была закомментирована, так как она уже объявлена в системных модулях (компилятор выдавал ошибку "Forward declaration not solved")

## Files modified
- `Base/Apus.Core.pas` — добавлены объявления и реализации платформенных примитивов, секция `uses` в реализации
- `Base/Apus.CrossPlatform.pas` — удалены перемещённые функции, добавлен `Apus.Core` в `uses`

## Files NOT modified (and why)
- Другие файлы не изменялись, так как задание ограничивалось только этими двумя файлами
- `MemoryBarrier` был закомментирован, а не удалён полностью, чтобы сохранить структуру кода для возможного будущего использования

## Test results
- Compilation 64-bit: OK (с предупреждениями и заметками)
- Compilation 32-bit: OK (с предупреждениями и заметками)
- Tests passed (64-bit): 128 из 128
- Tests passed (32-bit): 128 из 128
- Все существующие тесты `TestCore.dpr` проходят успешно

## Notes
- Функция `GetTickCount` для iOS оставлена с заглушкой `// TODO: iOS GetTickCount implementation`, как указано в задании
- Функция `IsDebuggerPresent` для iOS возвращает `false`, так как iOS не имеет `ptrace` в том же виде, что и другие UNIX-системы
- Функция `Sleep` для iOS использует `NSThread.sleepForTimeInterval`
- Предупреждение компилятора о том, что `Sleep` не может быть встроенной функцией, игнорируется (это нормально для платформозависимых функций)
- Изменения соответствуют стилю кодирования проекта (2 пробела для отступов, отсутствие пробелов вокруг операторов и т.д.)