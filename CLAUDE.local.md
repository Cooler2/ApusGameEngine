# Local notes — branch feature/r-05

## Контекст ветки
Ветка `feature/r-05`. Работаем в два этапа:

1. **Предварительный рефактор UI** (TUIElement cleanup) — подготовка к R-05:
   - убираем лишние поля из TUIElement (hint*, scrollbars → TUIScrollable)
   - цель: облегчить класс перед тем как вводить новую style-систему

2. **R-05 — Style System Rework** — основная задача:
   - заменяем `styleClass:byte` + `styleInfo:String8` на полноценную style-систему
   - убираем `font/color` из TUIElement (переходят в style)
   - вводим Drawer, Style, ResolvedStyle, state-модель, cascade, transitions
   - подробности: `Work/reports/R-05_notes.md`

## Принятые решения по R-05
Все в `Work/reports/R-05_notes.md`. Ключевые:
- `styleInfo` → переименовывается в `style`
- `styleClass` → заменяется на ссылку на Drawer-объект (class-based, не экземпляр)
- Drawer fallback по предкам → default style если нигде не задан
- `font/color` → только через style resolver
- Состояния (hover/pressed/disabled) — открытый набор, элемент сам задаёт через `SetState`
- Табличные стили: `@button` — множественные ссылки, приоритет по порядку
- Синтаксис: CSS-like текст + patch-операции (+key:val / -key / +@ref)
- Инвалидация кэша: dirty-каскад (не версионирование)
- Transitions: обязательная часть, связать с AnimatedValue
- Переменные: через Apus.Publics
- Шрифты: хэндлы как threadvar в render-потоке; style resolver для UI-элементов
- Профили Drawer: DefaultStyle / RichImageStyle / AdvancedStyle — общий базовый интерфейс

## Текущий статус рефактора TUIElement
- [x] `hintIfDisabled`, `hintDelay`, `hintDuration` → убраны из полей, доступ через `attributes.Item`
- [x] `scrollerH`, `scrollerV` → вынесены в `TUIScrollable`; `TUIImage`, `TUIListBox` наследуют его; `TUIScrollBar.Link` принимает `TUIScrollable`
- [x] `font`, `color` → убраны (2026-03-24); rendering через StyleFont()/GetStyleColor()
