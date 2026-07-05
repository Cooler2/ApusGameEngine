# R-30: устройство iOS lifecycle shell

## Зачем нужен shell

Shell — минимальное iOS-приложение, проверяющее границу между Xcode, SDL2 и
Pascal до подключения всего движка. Xcode отвечает за Mach-O executable,
структуру `.app`, подпись, provisioning и встраивание dynamic frameworks.
Pascal-код собирается FPC как static archive и линкуется внутрь executable.

Shell не является демонстрацией движка. Его задача — отдельно доказать, что
следующая цепочка работает на актуальном Xcode и iOS:

```text
iOS -> native main() -> Pascal bootstrap -> SDL/UIKit lifecycle
    -> Pascal frame callback -> engine
```

## Почему остаётся `main.c`

iOS запускает нативный Mach-O executable с символом `main`. Pascal у нас
подключён как библиотека, а SDL2 — как dynamic framework; ни один из них не
является готовым executable приложения. Поэтому Xcode target должен содержать
точку входа.

Для неё достаточно обычного C, Objective-C здесь не требуется. Целевой
`main.c` должен быть тривиальным адаптером C ABI:

```c
extern int ApusIOSMain(int argc, char *argv[]);

int main(int argc, char *argv[])
{
  return ApusIOSMain(argc,argv);
}
```

В `main.c` не должно быть SDL window, GLES, обработки событий или логики
движка. C нужен только потому, что Xcode/iOS ожидают нативную точку входа.

## Почему SDL вызывается из Pascal

В движке уже есть Pascal binding `extra/sdl2/sdl2.pas`. Поэтому после входа в
`ApusIOSMain` все обычные SDL-вызовы следует выполнять из Pascal:

1. Вызвать `SDL_UIKitRunApp`, передав Pascal callback запуска приложения.
2. В callback создать SDL window и GLES 3 context.
3. Зарегистрировать `SDL_iPhoneSetAnimationCallback`.
4. В frame callback обрабатывать SDL events и выполнять кадр движка.
5. При завершении освободить SDL-ресурсы.

Так SDL API не дублируется в C, а вся платформенная логика остаётся в Pascal и
использует тот же binding, что остальные SDL-платформы движка. Нативный слой
остаётся узким и стабильным.

## Особенность FPC static archive

Обычная Pascal-программа автоматически запускает RTL и секции
`initialization`. FPC сохраняет тот же механизм и для библиотеки, попавшей в
приложение как static archive.

Object библиотеки содержит Mach-O constructor `__mod_init_func`, указывающий
на stub вызова `_FPC_LIBMAIN`, и destructor `__mod_term_func`, указывающий на
`fpc_lib_exit`. При линковке current Apple linker преобразует constructor в
секцию `__TEXT,__init_offsets`; в проверенном executable offset `0x4270`
совпадает с адресом generated `__sysinitcallthrough` stub. Destructor остаётся
в `__DATA_CONST,__mod_term_func` и указывает на `fpc_lib_exit`.

Таким образом, dyld инициализирует FPC RTL и Pascal units до входа в C `main`,
а при выгрузке выполняет финализацию. Вручную вызывать `_FPC_LIBMAIN` или
`fpc_lib_exit` не нужно и опасно: это привело бы к двойной инициализации или
финализации. Для сохранения constructor object Pascal archive подключается
через `-force_load`.

## Что доказано текущим probe

Текущая версия shell уже реализует целевую границу: C `main` вызывает только
`ApusIOSMain`, а Pascal вызывает `SDL_UIKitRunApp`, создаёт SDL window/GLES
context и регистрирует frame callback. Она доказывает:

- линковку UIKit/SDL2/GLES/Pascal текущим Apple linker;
- запуск SDL UIKit entry point;
- наличие callback boundary между SDL и Pascal;
- включение generated FPC constructor/finalizer в финальный executable;
- arm64 Mach-O с minimum iOS 15.0 и SDK 26.5.

SDL C headers приложению не нужны: C-код не вызывает SDL, а Pascal использует
существующий binding `extra/sdl2/sdl2.pas`.

## Файлы и зависимости

- `app/main.c` — минимальный native entry с одним вызовом `ApusIOSMain`.
- `pascal/r30_pascal.lpr` — Pascal static library/probe.
- `R30Shell.xcodeproj` — unsigned device target для gate-zero.
- `build.sh` — воспроизводимая сборка FPC archive и Xcode application.
- `redist/ios/SDL2.framework` — только runtime-файлы framework: бинарник и
  `Info.plist`.

Generated `build` и `DerivedData` игнорируются и могут быть удалены. Исходники
и воспроизводимые runtime-зависимости не должны храниться только в `/tmp`.
