# Ревью качества кода движка Apus — отчёт

Объект: 108 модулей (`Base/Apus.*.pas` — 55, `Apus.Engine.*.pas` — 53), ветка `engine5` на момент коммита `9aec3751`
(перевод комментариев и удаление deprecated уже учтены). `Game/`, `legacy/`, `demo/`, `tests/` не рассматривались.
Изменений в код не вносилось, ничего удалять не предлагается — только описание.

## 1. Метод и границы

Что сделано:

1. Каталог готовых вызовов движка (Core: `Min/Max/Clamp/Sat/Lerp/Swap/IfThen/Toggle/Align*`, `Mem.*`, `Bits.*`
   (`HasAny/HasAll/SetFlag/Clear/Modify/Get/GetBits/SetBits/Pack/GetByte/GetWord`), `Sort.*`, `Time.*`; Strings: методы `String8`
   и `Strings8` — `StartsWith/EndsWith/Contains/Left/Right/Substr/Split/Join/Trim/Unquote/Add/...`; Conv; Colors;
   RTL: `IncludeTrailingPathDelimiter`, `Insert/Delete` для динамических массивов).
2. Автоматический поиск по **всем** 108 модулям «ручных» эквивалентов этих вызовов (≈40 шаблонов), точных и «с переименованием»
   копий кода (окна 8–9 строк), неиспользуемых локальных переменных, выражений с неочевидным приоритетом операторов,
   нарушений форматирования из `CLAUDE.md`.
3. **Каждое** найденное место просмотрено в контексте; в отчёт попало только то, что оценено как неоправданное
   (оправданные случаи собраны в разделе 5, чтобы их не поднимали повторно).
4. Полностью прочитаны `Apus.Engine.UIShapes` и `Base/Apus.Regions`; точечно (по 30–200 строк контекста) — ≈90 мест в 45 модулях.

Чего **нет**: построчного чтения всех ~91 тыс. строк. Находки категорий «длинная процедура» и «неочевидное выражение»
для модулей, не попавших в точечное чтение, получены по метрикам; там это отмечено («по длине»). Модуль, который в списке
отсутствует, не гарантированно чист — он просто не дал срабатываний на перечисленные шаблоны.

Серьёзность: **A** — вероятная ошибка/ловушка, **B** — заметное усложнение сопровождения, **C** — косметика/мелочь.

## 2. Сводка

| Группа | Находок | Из них A | Главные места |
|---|---|---|---|
| Ручное добавление/удаление в массив (3.1) | 12 | 0 | Sound, SDLplatform, ImageTools, HttpGameServer |
| Ручные строковые операции (3.2) | 16 | 0 | Sound.EventHandler, CmdProc, Files/Logging/SCGI, TextUtils |
| Ручные битовые и цветовые операции (3.3) | 14 | 0 | Window, DefaultStyle, Images, теги клавиш |
| Ручные Clamp/Swap/Lerp/Sat (3.4) | 9 | 0 | Window, GfxFilters, Utils, Draw |
| Неочевидный приоритет операторов (3.5) | 6 (≈186 строк в 38 файлах) | 1 | GameApp:1153, SceneEffects, Tools, Colors, FastGFX |
| Неоправданные дубли (3.6) | 16 | 0 | OpenGL, Window, ResManGL, Style/UITypes, HttpRequests, сеть |
| Длинные процедуры (3.7) | 14 | 1 | UdpTransport `TNetThread.Execute` |
| Мёртвый код, заглушки, неиспользуемое (3.8) | 11 | 3 | Regions, UIShapes, OpenGL |
| Оформление (3.9) | 8 | 0 | ControlFiles, UIShapes/Regions |

## 3. Находки

### 3.1. Ручное добавление и удаление элементов массива

Для `array of T` в движке есть `Strings8.Add/Insert/Delete/Remove` (Strings.pas), `TArray<T>.Add/Remove/Pop` (Types.pas),
`IntArray.Add/Remove`; для остальных типов работает `a:=a+[x]` (FPC ≥3.0, Delphi ≥XE7) и `Insert/Delete` из System.
Шаблон «SetLength(+1); a[high(a)]:=x» — три строки на одну операцию и лишнее обращение к `high`.

| # | Место | Что сделано вручную | Чем заменить | Сер. |
|---|---|---|---|---|
| A1 | `ImageTools.pas:403` | `names:Strings8`: `SetLength(names,length(names)+1); names[high(names)]:=…` | `names.Add(fname+EXTENSIONS[i])` | B |
| A2 | `SDLplatform.pas:808` | `dropList:Strings8`: то же (`SetLength(dropList,…+1); dropList[high]:=ust`) | `dropList.Add(ust)` | B |
| A3 | `SDLplatform.pas:167` | `sdlWindows:array of TSDLGLWindow` | `sdlWindows:=sdlWindows+[self]` | C |
| A4 | `Sound.pas:942, 1013, 1441` | `fileGroups`, `filePlaybacks`, `commands`: SetLength+присваивание ×3 | `+[…]` или `TArray<T>.Add` | B |
| A5 | `Sound.pas:1060` | удаление «подменой последним + SetLength(-1)» (то же `HttpGameServer.pas:196`, `TCP.pas:175`) — один и тот же приём в 3 модулях с разными массивами | один общий `RemoveAt/Remove` (или `TArray<T>.Remove(el,keepOrder=false)`, он именно это и делает) | B |
| A6 | `HttpGameServer.pas:181` | `fUsers`: SetLength+присваивание | `fUsers:=fUsers+[u]` | C |
| A7 | `Resources.pas:551` | `parent.views`: SetLength+присваивание | `+[self]` | C |
| A8 | `RobotAPI.pas:250` | `newPending`: SetLength+присваивание внутри цикла фильтрации | `newPending:=newPending+[allRequests[i]]` | C |
| A9 | `Game.pas:551` | `customPoints`: SetLength + две строки `.x/.y` | `customPoints:=customPoints+[Point(round(x),round(y))]` | C |
| A10 | `TextDraw.pas:231` | `limitedFonts:array of TObject` — линейный поиск + SetLength | `TArray<TObject>.Contains/Add` | C |
| A11 | `Window.pas:1162` | растёт на 1 при каждой вставке (`SetLength(items,count+1)`) | оправдано хранением `count`; но рост по 1 даёт O(n²) — использовать запас (как в `NinePatch.pas:354`) | C |
| A12 | `HashMaps.pas:875, 878, 1071–1072, 1153, 1164, 1316, 1327`; `OpenGL.pas:1325`; `MeshShapes.pas:368` | циклы `for i:=… do links[i]:=-1` | `Mem.FillD(links[0],length(links),$FFFFFFFF)` (`Mem.FillD` быстрее и короче) | C |

### 3.2. Ручные строковые операции

| # | Место | Что сделано вручную | Чем заменить | Сер. |
|---|---|---|---|---|
| S1 | `CmdProc.pas:154–156` | префикс: `copy(st,1,length(oper))=oper`; суффикс: `copy(st,length(st)-length(oper)+1,length(oper))=oper`; середина: `pos(…)>0` | `st.StartsWith(oper)`, `st.EndsWith(oper)`, `st.Contains(oper)` — три разных стиля в трёх соседних строках | B |
| S2 | `Sound.pas:1168–1193, 1219–1221` | после `event.StartsWith('PLAYFILE\')` длина префикса «зашита» числом: `copy(orig,10,length(orig))`, `copy(event,11,…)`, `copy(event,12,…)`, `delete(event,1,10)`. При смене имени команды число придётся менять вручную, ошибка не диагностируется. | выделить `function StripPrefix(const st,prefix:String8; out rest:String8):boolean` (или `rest:=event.Substr(length('PLAYFILE\')+1)`) | **B** |
| S3 | `Sound.pas:1219` | `pos('PLAYMUSIC\',event)=1` — сканирует всю строку ради проверки начала; в этой же функции выше используется `StartsWith` | `event.StartsWith('PLAYMUSIC\')` | C |
| S4 | `Sound.pas:464, 547, 571, 577, 643, 659` | шесть `UpperCase {TODO: use st.ToUpper}(…)` | `.ToUpper` (как и просит TODO) | C |
| S5 | `HttpGameClient.pas:324, 590, 594`; `SCGI.pas:458–459`; `Translation.pas:129`; `HttpRequests.pas:376, 809` (`pos('CONTENT-DISPOSITION:',UpperCase(lines[i]))=1`) | проверка начала строки через `pos(…)=1` / `copy(…,1,n)='…'` | `StartsWith(prefix[,ignoreCase=true])` — для регистронезависимого случая он вообще заменяет `UpperCase`+`pos` без копирования | C |
| S6 | `Style.pas:301–302` | `(t<>'') and (t[length(t)]='%')` → `Copy(t,1,length(t)-1)` | `t.EndsWith('%')` + `SetLength(t,length(t)-1)` (или `t.Left(length(t)-1)`) | C |
| S7 | «добавить/убрать завершающий разделитель пути» в 6 местах: `Files.pas:286, 706`; `Logging.pas:391`; `SCGI.pas:1009`; `CustomStyle.pas:344`; `ControlFiles.pas:1753` | везде свой вариант `if (s<>'') and (s[length(s)]=…) then …`; в `SCGI.pas:1009` и `CustomStyle.pas:344` разделитель `'\'` зашит (на Linux получится путь вида `dir\`, при этом `CustomStyle` проверяет оба разделителя, а добавляет только `'\'`) | `IncludeTrailingPathDelimiter` / `ExcludeTrailingPathDelimiter` (RTL) или `s.EndsWith(PathDelim)` | B |
| S8 | `TextUtils.pas:52–53` (`ParseJSON`) | снятие кавычек: `(key[1]='"') and (key[length(key)]='"') or (key[1]='''') and … then key:=copy(key,2,length(key)-2)` — длинное, и приоритет `and`/`or` приходится держать в голове | `key:=key.Unquote` (есть `Quote/Unquote`) | B |
| S9 | `TextUtils.pas:42` | `(json[1]='{') and (json[length(json)]='}')` → `copy(json,2,length(json)-2)` | `json.StartsWith('{') and json.EndsWith('}')` + `Substr/Remove` | C |
| S10 | `HttpGameClient.pas:371–382` | свой `StrToHex` с таблицей из 16 символов; в этом же модуле на строке 508 уже вызывается `Conv.EncodeHex` | `Conv.EncodeHex(st)` (удалить локальную копию) | B |
| S11 | `CmdProc.pas:313–314`; `Style.pas:278`; `RobotAPI.pas:118`; `TextUtils.pas:196, 198`; `HtmlTree.pas:177`; `Publics.pas:355`; `SCGI.pas:487`; `ControlFiles.pas:757` | `delete(s,1,1)` после проверки первого символа (снятие префикса `$`, `%`, `#`) | оправдано, если один раз; но в `RobotAPI.pas:117–118` цикл `while … Delete(result,1,1)` удаляет по символу с копированием строки — O(n²). Заменить на поиск индекса и один `Substr` | C |
| S12 | `Clipboard.pas:95` | `(length(result)>0) and (result[length(result)]=#0)` | `result.LastAnsiChar=#0` (есть метод) | C |
| S13 | `HttpServer.pas:437, 458` | `if x.EndsWith(#13) then SetLength(x,length(x)-1)` — дважды подряд | вспомогательная функция `ChopCR` / один вызов `lines:=text.SplitLines` (уже есть, режет по `#13`, `#10`, `#13#10`) | C |
| S14 | `Engine.Style.pas:731–743`; `CmdProc.pas:227, 258`; `ShadersGL.pas:508–509` | `Copy(t,N,length(t)-N+1)` с «зашитой» арифметикой длин (`7`, `6`, `3`, `8`) | `t.Substr(N)` (по умолчанию «до конца», без вычитания длины) | C |
| S15 | `UIScript.pas:296–299` | `copy(fieldname,p+1,100)` — магическое `100` вместо «до конца» | `Substr(p+1)` | C |
| S16 | `Strings.pas`/`Conv.pas` — локальные таблицы `HexChars` | две независимые таблицы `'0123456789ABCDEF'` (`Conv.pas:118`, `Strings.pas:830`) | одна общая константа | C |

### 3.3. Ручные битовые и цветовые операции

| # | Место | Что сделано вручную | Чем заменить | Сер. |
|---|---|---|---|---|
| B1 | `Window.pas:751–752`, `1755–1756` | `if pressed then x:=x or bit else x:=x and not bit` (дважды: `reqButtons`, `mouseButtons`) | `Bits.Modify(mouseButtons,bit,pressed)` — именно для этого он и сделан | B |
| B2 | `Window.pas:1521`, `DefaultStyle.pas:183, 187`, `TextFXStyle.pas:116` | `x:=x and not mask` | `Bits.Clear(x,mask)` | C |
| B3 | `DebugOverlays.pas:134`; `UIWidgets.pas:1190–1191`; `Notifications.pas:495, 499`; `Window.pas:1752`; `SDLplatform.pas:1049`; `GfxFormats.pas:682`; `OpenGL.pas:1513–1516` (`glColorMask((curmask and 4)>0, (curmask and 2)>0, …)`) | `(v and mask)>0` / `<>0` — три разных формы записи одной проверки (`>0`, `<>0`, `=mask`) | `Bits.HasAny(v,mask)`; для одного бита `Bits.Get(v,index)` | C |
| B4 | `API.pas:1086, 1108`; `Sound.pas:804`; `TextDraw.pas:248`; `Tools.pas:143, 146`; `UIScene.pas:788`; `WindowsPlatform.pas:377, 441`; `Engine.DebugOverlays.pas:147`; `DebugDraw.pas:299–301`; `Draw.pas:1491`; `Notifications.pas:132`; `TweakScene.pas:444–445`; `GfxFilters.pas:1340`; `GfxFormats.pas:819, 925`; `HttpServer.pas:151` | `(x shr 16) and $FF`, `(x shr 8) and $FFFF` — ручное извлечение байта/слова (~30 мест) | `Bits.GetByte(x,2)`, `Bits.GetWord(x,1)`; для каналов цвета — методы `Color.*` | C |
| B5 | `Game.pas:472`; `GfxFormats.pas:711–712` (BE-чтение `(d[0] shl 24) or (d[1] shl 16) or …`); `Clipboard.pas:170`; `DebugDraw.pas:303`; `GfxFilters.pas:1355, 1385` | ручная упаковка; в `Colors` есть `Color.ARGB(a,r,g,b)`/`Color.RGB`, в Core — `Bits.Pack(b0,b1,b2,b3)`/`PackW` | заменить на вызов | C |
| B6 | `Images.pas:224` | `pc^:=pc^ and $FF00FF00 or (pc^ and $FF shl 16) or (pc^ and $FF0000 shr 16)` — обмен R и B | `Color.Swap(pc^)` (есть, inline) | **B** |
| B7 | `Colors.pas:242` | реализация `Color.Swap` записана через `+` без скобок (см. 3.5) — сама по себе оправдана, но является образцом, которому копируют стиль | поставить скобки | C |
| B8 | `Compress.pas:254` | `byte(data[1+curpos shr 3]) and (1 shl (7-(curpos and 7)))>0` | `Bits.Get` с учётом порядка бит (в `Types.pas` у `TBitStream` есть `GetBit`) | C |
| B9 | `GfxFormats.pas:202–203`, `Clipboard.pas:157`, `ResManGL.pas:439–440`, `UIShapes.pas:99, 123`, `Regions.pas:136, 160` | `(w+3) div 4`, `4*((w*bpp+31) div 32)` — ручное выравнивание/размер строки | `AlignUp(…)`; размер строки растра 4 байта-выровненный сейчас посчитан в **трёх** местах разными формулами (`Clipboard`, `UIShapes`, `GfxFormats:1384`) — выделить одну функцию | B |
| B10 | `HashMaps.pas:1151, 1314` | `while (hMask>estimatedCount) and (hMask>$1F) do hMask:=hMask shr 1` | `NextPow2(estimatedCount)-1` (с границами) | C |
| B11 | `Engine.Game.pas:456`, `GameApp.pas:381`, `UITypes.pas:1280/1287/1306`, `Window.pas:1547/1736/1737`, `WindowsPlatform.pas:444–456` | сигналы с тегом `code+scan shl 16` — «упаковка в один integer» записана вручную более десяти раз; формат тега (`keycode | scan<<16`, `ch | scan<<8`, `key | shift<<8`) нигде не описан; а на другой стороне распаковка `(tag shr 8) and $FFFF` (`Sound.pas:804`, `API.pas:1086`) | пара функций `MakeKeyTag/KeyTagCode/KeyTagScan` рядом с определением сигналов | B |
| B12 | `Scene.pas:446–447` | `(k shr 24) and 1<>0`, `k and $FF`, `(k shr 8) and $FFFF` — распаковка того же формата (`Game.pas:472`) в другом модуле | то же | B |
| B13 | `UIRender.pas:104` | `$80FFFFFF xor ($FFFFFF*((CoreTime.Ticks shr 8) and 1))` — мигание рамки; чтобы понять, нужно «вычислить» выражение в голове | `if Bits.Get(…,8) then … else …` или именованная константа | C |
| B14 | `Draw.pas:1411` | `b1^:=b1^ div 2+32; b2^:=(b2^*3+255) shr 2;` — магические константы без комментария | комментарий/именованные константы | C |

### 3.4. Ручные Clamp / Swap / Lerp / Sat

`Clamp`, `Sat`, `Lerp`, `Max/Min`, `Swap` — `inline`, цены вызова нет, поэтому «в горячем цикле» не оправдание.

| # | Место | Что сделано вручную | Чем заменить | Сер. |
|---|---|---|---|---|
| M1 | `Utils.pas:191–192, 199–200, 210–211, 219–220, 229–230` | пять раз подряд `if x<0 then x:=0; if x>1 then x:=1;` в `Spline0/1/2/2rev/Spline` | `x:=Sat(x)` | B |
| M2 | `GfxFilters.pas:1352–1354`, `1379–1384`, `343–349, 382` | `v:=round(…); if v<0 then v:=0; if v>255 then v:=255;` по 3–6 раз подряд | `Clamp(round(…),0,255)` (в 1352–1354 — три одинаковые строки) | B |
| M3 | `Window.pas:1302–1307` (6 строк `if x<0 then x:=0`), `Window.pas:1034–1035` | | `deltaUs:=Max(0,deltaUs)` (или цикл по открытому массиву) | C |
| M4 | `DebugOverlays.pas:77–79`, `Notifications.pas:133–134`, `TextFXStyle.pas:104–107`, `SoundSDL.pas:161–162`, `UIWidgets.pas:1597, 1605, 1612, 1621–1622`, `TweakScene.pas:390–391`, `SceneEffects.pas:567, 621, 632`, `Window.pas:1354–1356` | пара `if x<min then …; if x>max then …;` | `Clamp(x,min,max)` | C |
| M5 | `Draw.pas:1027–1032` | `v:=x1; x1:=x2; x2:=v;` ×4 с общей временной `v` (а `v` здесь ещё и имя координаты текстуры — `v1`, `v2` рядом) | `Swap(x1,x2); Swap(u1,u2); …` (перегрузка для `single` есть) | B |
| M6 | `FastGFX.pas:2003`; `GfxFilters.pas:949, 1058` (обмен буферов-указателей) | ручная тройка присваиваний | `Swap(a,b)` (перегрузки `single`/`pointer` есть) | C |
| M7 | `Utils.pas:193, 204, 213, 222`; `MeshShapes.pas:442, 444, 472, 473`; `NinePatch.pas:466, 476`; `TweakScene.pas:416`; `UIWidgets.pas:1606, 1613` | `a+(b-a)*t` | `Lerp(a,b,t)`; в `MeshShapes.pas:472–473` то же выражение повторено дважды в соседних строках | C |
| M8 | `GfxFilters.pas` `DraftBlur32X/Y` (≈415–418, ≈471–474) (`xc:=x; if x<0 then xc:=0; if x>=sizex then xc:=sizex-1`) | | `Clamp(x,0,sizex-1)` | C |
| M9 | `UIWidgets.pas:2116, 2126`, `CustomStyle.pas:135, 139, 275` | `if n<0 then n:=0` | `Max(0,n)` | C |

### 3.5. Выражения, в которых легко ошибиться (приоритет операторов)

В Pascal `and`, `shl`, `shr` имеют **приоритет умножения**, а `+`, `-`, `or`, `xor` — сложения. Поэтому `a shl 24+b` читается как `(a shl 24)+b`,
а `x and $FF+y` — как `(x and $FF)+y`. Это формально верно, но противоречит привычке (C/Python), и скобки отсутствуют.
Найдено ≈186 строк в 38 файлах (больше всего: FastGFX 36, Conv 25, LongMath 16, TextDraw 12, SceneEffects 11, GfxFormats 10, Images 8).
Примеры и места, где риск максимален (сочетание `+` с `and/shl` без скобок на обеих сторонах):

| # | Место | Выражение | Проблема | Сер. |
|---|---|---|---|---|
| E1 | `GameApp.pas:1153` | `L:=50+round(-256*i/13-CoreTime.Ticks*0.3) and 255;` | разбирается как `50+(round(…) and 255)` → диапазон 50..305; далее `cardinal(L shl 24)` — при L>255 альфа «заворачивается» (`305 shl 24` в 32 битах даёт старший байт `$31`). Вероятно, имелось в виду `(50+round(…)) and 255` или ограничение сверху. **Вероятная ошибка** (проверить на экране загрузки) | **A** |
| E2 | `Colors.pas:263` (`Color.Scale`) | `color and $FFFFFF+round(alpha*(color and $FF000000)) and $FF000000` | два `and` и `+` в одной строке; корректность опирается на неявный порядок и на то, что `single` точно представляет `color and $FF000000` (числа до 2^32 в 24-битной мантиссе) | B |
| E3 | `Colors.pas:242` (`Color.Swap`), `Tools.pas:146, 525, 556`, `SceneEffects.pas:253, 560, 568, 578, 587, 596, 604, 612, 622, 633`, `TextDraw.pas:883, 1036, 1045, 1361`, `ImageTools.pas:372`, `UITypes.pas:1280/1287/1306`, `Window.pas:1547/1736/1737`, `WindowsPlatform.pas:444–456`, `Game.pas:456` | `x shl 24+$808080`, `fontHandle and $FF00FFFF+v shl 16`, `ord(key)+scanCode shl 16` | см. заголовок раздела: корректно, но ни одной скобки | B |
| E4 | `GameApp.pas:637` | `(1000*random(50000)+CoreTime.Ticks shl 8+round(now*1000)) mod 100000000` | `shl` внутри суммы с `*`; к тому же результат — ненадёжный идентификатор | C |
| E5 | `TextDraw.pas:1326, 1331, 1408, 1413` | `y+fHeight shr 1`, `queryY<y+fHeight shr 1` | `y+(fHeight shr 1)`; в сочетании с `<` — легко прочесть как `(y+fHeight) shr 1` | C |
| E6 | `FastGFX.pas:1974, 1997, 2041, 2082` | `color and $FFFFFF+round((color shr 24)*a) shl 24` — одно и то же выражение 4 раза | выделить `Color.SetAlpha`/`ScaleAlpha` (в `Colors` уже есть `Color.Scale/SetAlpha`) | B |

Рекомендация: единое правило — скобки вокруг каждого `shl/shr/and`, если рядом `+ - or xor` (можно проверять тем же поиском).

### 3.6. Дублирование, которое не оправдано

| # | Где | Что дублируется | Как правильнее | Сер. |
|---|---|---|---|---|
| D1 | `UIShapes.pas:74–155` ↔ `Regions.pas:120–192` | `TUIBitmapShape` и `TBitmapRegion`: `LoadFromBMP`, `CreateFromImage`, `IsOpaque`/`TestPoint` — посимвольные копии (≈75 строк, включая локальный `TBitmapHeader`); `TUIBasicShape.Create/Invert` ↔ `TBasicRegion.Create/Invert` | один класс, второй — наследник/алиас | B |
| D2 | `OpenGL.pas:990–1020` ↔ `1079–1109` (`DrawIndexed` / `DrawInstanced`) | 24 одинаковые строки подготовки (shader.Apply, ветка `useStream`, привязки буферов), отличается только вызов отрисовки. Обе копии содержат мёртвую ветку (см. H-2) | вынести «PrepareIndexedDraw» | B |
| D3 | `Window.pas:2195–2208` (в `RenderFrame`) ↔ `2270–2283` (в `RenderScenes`) | сортировка активных сцен по Z — 14 одинаковых строк вставкой с флагом `fl` и индексами с 1 (`sc[1..50]`, `sc[j+1]:=sc[j]`); ловушка: при `n=0` особый случай, при несрабатывании — отдельный `if fl`, `ASSERT(n<high(sc))` | одна `function GetSortedActiveScenes` или `Sort.ByInt(…)` (в Core есть) | **B** |
| D4 | `ResManGL.pas:2370–2425` | `TVertexBufferGL` и `TIndexBufferGL`: `PublishUpdate`, `WaitForPublish`, `ResetPublishState` — по 3 одинаковых метода (≈28 строк); `AllocVertexBuffer` ↔ `AllocRawVertexBuffer` (≈16 строк, различается только конструктор и метка ошибки) | общий предок/хелпер для sync-объекта | B |
| D5 | `Style.pas:507–516` ↔ `UITypes.pas:1599–1607` ↔ `1639–1658` | разбор цвета: `ParseStyleColor(s); if (result=0) and (s<>'0') then result:=defVal` — три копии; `GetBaseStyleColor`/`GetBaseStyleNumber` — одинаковые цепочки «подняться по `parent` в поисках ключа» (12 строк ×2) | `ParseStyleColorDef(s,defVal)` и `LookupInheritedValue(key)` | B |
| D6 | `HttpRequests.pas:371–384` (ветка FPC) ↔ `804–818` (ветка Delphi/WinInet), оба в `ExecutePostRequest` | определение multipart-границы — 13 одинаковых строк; сама платформенная часть различается, эта — нет | вынести `DetectMultipartBoundary(postData,boundary)` | B |
| D7 | `HttpServer.pas:190–203` ↔ `234–247` | разбор `k=v&…` дважды (UrlDecode, значение `'TRUE'` по умолчанию) | `ParseQueryPairs(str,names,values)` | B |
| D8 | `TCP.pas:348–360` ↔ `567–578` | `FlushSendData` у сервера и клиента: цикл Send/WSAEWOULDBLOCK/Log одинаковый, различается лишь реакция на ошибку | общий `TrySend(sock):integer` | C |
| D9 | `HttpGameClient.pas:121–225` ↔ `UdpTransport.pas:153–335` | iOS-`CheckInternetConnection`, декларации `THostEnt/gethostbyname/inet_addr` и разбор адреса (`GetInternetAddress` ↔ `ResolveAddress`) скопированы целиком (≈100 строк) между двумя модулями сети | общий модуль (в `Apus.Socket` уже есть сокетный слой) | B |
| D10 | `Logging.pas:102–131` (`FormatTimeStr`) | два одинаковых блока по 12 строк посимвольной сборки `HH:MM:SS.mmm`, различающихся только именами полей `TSystemTime` (`Hour` / `wHour` для FPC / Delphi). В Core есть `Time.Stamp` (`HH:MM:SS.mmm for logs`) | `Time.Stamp`, либо одна версия через локальные `h,m,s,ms` | B |
| D11 | `UnicodeFont.pas:134–153` ↔ `Colors.pas:175–193` | хвост смешивания (`opaque background` / `transparent background`, константы `258`, `65792`, `66051`) повторён | вызвать `Color.Blend(c1,c2)` после масштабирования `c2.a` | B |
| D12 | `GfxFilters.pas:507–567` ↔ `567–630` (`LightBlur8` / `Blur8`) и `396–452` ↔ `452–507` (`DraftBlur32X/Y`) | края/углы изображения (≈35 строк) скопированы, отличается только шаг строки `tPitch`; горизонтальный и вертикальный проход отличаются лишь осью | параметризовать шаг | B |
| D13 | `Conv.pas:166–230` | `Conv.ToInt` для `String8` и `UnicodeString` — копия на 30 строк (меняется только `CharInSet`); `HexToInt` ×2; `Conv.pas:436–500` — `ToStr` для integer/cardinal/int64/uint64: четыре копии одного алгоритма с разными размерами буфера | внутренний `UIntToStr(u:uint64;neg:boolean)`; для Unicode-вариантов — преобразование в `String8` и вызов основного | C |
| D14 | `CustomStyle.pas:418–575` (`GetField`, 157 строк) и `UIScript.pas:289–470` (183 строки) | сотни раз повторён блок `if prop='X' then begin result:=@item^.x; varClass:=T…; end else` — двухстрочная операция на 3 строки + `case` по первой букве вручную вместо хеш-таблицы | табличная регистрация `(имя, смещение, тип)`; заметно сократит оба файла и сделает опечатку в имени поля ошибкой регистрации, а не молчаливым «не найдено» | B |
| D15 | `RSA.pas:110–190` ↔ `193–275`; `LongMath.pas:960–1010` ↔ `1033–1083` | алгоритмы (`IsPrime`, деление) целиком продублированы под `TBigInt`/`TBigInt2` (разные размеры) | не оправдано, но унаследовано; если типы нужны оба — параметризовать размером | C |
| D16 | `HashMaps.pas:1150–1165` ↔ `1313–1328` | `TSimpleHash`/`TSimpleHashS`: `Create`/`Clear` идентичны | общий базовый класс | C |

### 3.7. Длинные процедуры

Длина — от заголовка до конца тела (комментарии и вложенные подпроцедуры включены). Подтверждено чтением — «чт.», по метрике — «длина».

| # | Место | Строк | Комментарий | Сер. |
|---|---|---|---|---|
| L1 | `UdpTransport.pas:705` `TNetThread.Execute` | ≈530, вложенность до 11 | чт.: три стадии в одном цикле (приём пакетов ≈300 строк, отправка ≈60, обслуживание соединений/таймауты ≈90); 18 локальных переменных (`i,j,k,l`, `fl`, `d,dd`, `c`, `t`…), одно разбиение — две вложенные процедуры `AddNote`/`DropConnection` | **A** |
| L2 | `WindowsPlatform.pas:401` `WindowProc` | 262 | длина; оконная процедура — одна `case` по сообщениям, оправдана частично; стоило бы вынести обработчики `WM_KEY*`, `WM_MOUSE*`, `WM_SIZE` | C |
| L3 | `ImageTools.pas:431` `LoadFileImage` | 160 | длина | B |
| L4 | `Game.pas:2063` `ExtraWindowLoop` (162), `1862` `RenderAndPresentFrame` (127) | | длина | B |
| L5 | `Window.pas:2132` `TWindow.RenderFrame` | 124 | чт.: сортировка сцен, вложенные try/except, кадр-лог; см. D3 | B |
| L6 | `GameApp.pas:690` `Prepare` (139) | | длина | B |
| L7 | `SceneEffects.pas:508` `TShowWindowEffect.DrawScene` | 137 | длина | B |
| L8 | `SDLplatform.pas:692` `HandleEvent` (136) | | длина; `case`, частично оправдана | C |
| L9 | `HttpRequests.pas:309` (FPC, 110 строк) и `691` (Delphi/WinInet, 183 строки) `ExecutePostRequest` | | чт.: две платформенные реализации с общим куском (D6) | B |
| L10 | `GfxFormats.pas:231` `LoadTGA` | 163 | длина | C |
| L11 | `Publics.pas:237` `EvalFloat` (149) | | длина (разбор выражений рекурсивным спуском в одной функции) | B |
| L12 | `TextDraw.pas:1262` `BuildVertexData` (175) | | длина | B |
| L13 | `Draw.pas:1683` `TDrawer.Band` (112) | | чт.: плюс неиспользуемая переменная (H-4) и закомментированная объявленная `vrt` | C |
| L14 | `CustomStyle.pas:108` `DrawButton` (123), `DefaultStyle.pas:647` `DrawUIScrollbar` (124), `UIScene.pas:339` `DispatchMouseMove` (118), `HttpGameClient.pas:252` `EventHandler` (118), `EventMan.pas:367` `HandleEvent` (131), `SCGI.pas:1210` `TWorker.Execute` (124), `ResManGL.pas:1639` `AllocRenderTarget` (123), `ShadersGL.pas:496` `BuildFragmentShader` (124) | | длина | C |

Табличные `case`, которые длинны по природе (`ResManGL.GetGLformat` — 170 строк таблицы форматов, `Keys.pas:279–312`), в список не включены.

### 3.8. Мёртвый код, заглушки, неиспользуемое

| # | Место | Описание | Сер. |
|---|---|---|---|
| H1 | `Regions.pas` целиком (211 строк) | заглушки: `TBasicRegion.TestPoint` без тела и без `result` (возвращает мусор), `TRectRegion.Create/IncludeRect/ExcludeRect` пустые, `TRectRegion` не реализует абстрактные `Invert/TestPoint` (экземпляр абстрактного класса); `TBasicRegion.CreateFrom` — `ASSERT(false,'Not implemented')` + 15 строк закомментированного черновика + 6 неиспользуемых локальных; реализация `TBasicRegion.Create` объявлена без параметров (стр. 71), секция названа `{ TRegion }`, деструктор `TBitmapRegion.Destroy` пуст и не вызывает `inherited`. Единственный потребитель — `BuildTest.dpr` (проверка компиляции); использование в `Tools.pas:224–250` целиком в комментарии | **A** |
| H2 | `OpenGL.pas:997, 1086` | `useStream:=false; if useStream then … else …` — первая ветка не выполнится никогда (≈8 строк мёртвого кода; `useStream` и `vertexCount` существуют только ради неё) в двух функциях; рядом TODO(low), что «поток без числа вершин небезопасен» — фактически отключено | **A** |
| H3 | `UIShapes.pas:159–188` | `TUIBasicShape`: `IsOpaque` всегда `false`, `CreateFrom` — `ASSERT(false)`; класс экспортирован через `Apus.Engine.UI.pas:74` как рабочий. В релизе `ASSERT` выключен — `CreateFrom` молча создаёт пустую форму | **A** |
| H4 | неиспользуемые локальные переменные (проверены: единственное вхождение — объявление) | `Draw.pas:1683` `Band` (`n`), `Draw.pas:1796` `Cover` (`w`,`h`), `Game.pas:1210` `PrepareRun` (`i`), `Game.pas:1503` `Delay` (`delta`), `ResManGL.pas:729` `TGLTextureArray.UploadInternalData` (`error`), `1317` `UpdateFilter` (`aTex`), `2005` `FreeImage` (`level`), `TweakScene.pas:129` `Create` (`i`), `280` `Draw` (`fl`), `Images.pas:230` `ConvertLine` (`buf`,`sp`), `338` `TBitmapImage.Create` (`palElSize`), `382` `Expand` (`x`,`c`), `TCP.pas:182` `AcceptNewConnection` (`i`), `Threads.pas:947` `MakeUniqueName` (`found`), `Network.pas:257` `UDPSocket2.Receive` (`m`,`pb`,`b`,`confbuf`) | C |
| H5 | `HttpGameClient.pas:396–431` | 35 строк закомментированного «старого» GET-кода внутри `SendMessages`, в комментариях — повреждённые символы (`�������� ������� GET`, стр. 404, 413) | B |
| H6 | `Draw.pas:79`, `UIScript.pas:197` | повреждённые символы в комментариях (U+FFFD) | C |
| H7 | `UIShapes.pas:74–77` | пустой `destructor Destroy; override; begin inherited; end;` (аналог в Regions — без `inherited`) | C |
| H8 | `Tools.pas:224–250` | `TTiledImage.GetRegion` — вся реализация в комментарии, функция возвращает `nil` | B |
| H9 | прочий закомментированный код | ≈75 фрагментов, больше всего: `ImageTools` 6, `UIScene` 4, `GameApp` 3, `SDLplatform` 3, `Sound` 3, `Tools` 3, `UITypes` 3 | C |
| H10 | `Regions.pas:9`, `UIShapes.pas:48` | вероятно лишний `uses Apus.Conv` в обоих модулях (в коде нет ни одного вызова Conv) — проверить компиляцией | C |
| H11 | `Game.pas:1304` `Timing` | локальная вложенная процедура внутри `onEngineEvent`, использующая переменные внешней (`fr`, `timerFrame`, `avgTime2`) — не баг, но затрудняет чтение (внешняя функция объявляет `t,fr:int64; p:TPoint`, часть из которых нужна только ей) | C |

### 3.9. Оформление

| # | Место | Описание | Сер. |
|---|---|---|---|
| F1 | `UIShapes.pas`, `Regions.pas` | отступ в 1 пробел внутри `begin…end` (смесь с 2-пробельным в конце файла), `var` в колонке 0, пробелы в сигнатурах (`(x, y: single): boolean`), разный регистр `setLength/Setlength`, `width:=w; height:=h;` на одной строке | C |
| F2 | `ControlFiles.pas:239–430` (`Q_StrToInt64` и соседние), `Log.pas` (4 строки), `UITypes.pas:992–994` (выравнивание — оправдано) | стиль Allman (`then` / `begin` на разных строках — ≈23 места), пробелы вокруг `:=` и `=` (≈31 строка) против правил `CLAUDE.md` | C |
| F3 | `Spatial.pas` (5), `NinePatch.pas` (4), `Core.pas` (2), `UIWidgets.pas`, `UITypes.pas`, `Strings.pas` (по 1) | `else`/`do`/`then` и `begin` на разных строках (`ControlFiles.pas` — ещё 23, см. F2) | C |
| F4 | `UIWidgets.pas:282`, `Lib.pas:117` | пробелы в конце строки | C |
| F5 | строки длиннее 160 символов (без таблиц данных `HtmlTree`, `TextUtils.pas:219–236`) | `API.pas:387, 618`, `Game.pas:43`, `Graphics.pas:154–155`, `OpenGL.pas:268, 828`, `Resources.pas:105`, `ShadersGL.pas:487, 496`, `Types.pas:477`, `Conv.pas:75`, `Socket.pas:101`, `Strings.pas:42, 153` — разбить | C |
| F6 | `Draw.pas:1027–1032`, `GfxFilters.pas:1352–1354` и др. | несколько операторов в одной строке (`if …; if …;` в GfxFilters ≈15 раз, `UIWidgets.pas:1605, 1612`) | C |
| F7 | 25 файлов без BOM (`UIShapes`, `Mesh`, `SteamAPI`, `GpuLayout`, `HttpGameServer`, `DefaultStyle`, `SceneEffects`, `NinePatch`, `Notifications`, `RobotAPI`, …) | `CLAUDE.md` требует сохранять BOM у существующих файлов; для новых — выбрать единое правило | C |
| F8 | `CustomStyle.pas`, `UIScript.pas` | в `GetField` ветки по первой букве: часть с `begin…end`, часть без — единого шаблона нет (см. D14) | C |

## 4. Приоритеты

1. **A**: `GameApp.pas:1153` (приоритет `and` — вероятная ошибка), `OpenGL.pas:997/1086` (мёртвая ветка в двух функциях),
   `UIShapes.TUIBasicShape` и весь `Regions.pas` (публично доступные «рабочие» классы-заглушки), `UdpTransport.TNetThread.Execute` (530 строк).
2. **B, дешёвые и безопасные**: S2 (магические длины префиксов в Sound), S7 (разделитель пути, три места не работают на Linux),
   S10 (дубль `StrToHex`), B1/B6 (`Bits.Modify`, `Color.Swap`), M1/M2/M5 (`Sat`, `Clamp`, `Swap`), D10 (`Time.Stamp`), D3, A1/A2/A4.
3. **B, требуют проектного решения**: D1, D2, D4, D5, D9, D14, B9 (размер строки растра), B11/B12 (формат тегов клавиш).
4. Остальное (C) — пакетно, по мере касания файлов.

## 5. Проверено и оставлено (оправдано, в находки не включено)

- Пары `single`/`double` в `Geom2D`/`Geom3D` (`TMat3.ToQuaternion` ↔ `TMat3d.ToQuaternion`, `Invert`, `Mul`, `TVec2` ↔ `TVec2d` — ≈20 пар по 10–24 строки): в Pascal нет дешёвого generic над арифметическими типами в записях с операторами; копии в одном файле, рядом, структура одинакова.
- Дублирование объявлений интерфейса и класса-реализации (`ITextDrawer` ↔ `TTextDrawer`, `IFileProvider` ↔ `TOSFileProvider`, `IThread` ↔ `TThread*`, `TSDLGLWindow` ↔ `TWinGLWindow` — список `override`): структурно обязательно.
- `Log.Debug/Info/Warn/Error/Force` в `Log.pas` — пары перегрузок по 4 строки: API-шаблон.
- `ShadersGL.pas:1080–1125` (`SetUniform` ×N перегрузок по 6 строк): перегрузки по типу значения, каждое тело — две ветки; допустимо.
- `Resources.pas:448–483` `TTexture.Fill(TPixelFillFunc)` ↔ `Fill(TPixelFillMethod)`: разные типы процедурных указателей, объединить нельзя без анонимных методов (недоступны в FPC 3.2).
- `Strings.pas:1228, 1239, 1252`, `1444, 1533`: поэлементные копии/сдвиги для управляемых типов.
- `Huffman.pas:66–70`: локальный `Swap(var a,b:cardinal)` — в `Core.Swap` нет перегрузки для `cardinal`; при желании добавить её в Core, сама копия оправдана.
- `Keys.pas:279–312` (таблица кодов) и `ResManGL.GetGLformat` — таблицы по природе.
- `HtmlTree.pas:89–109` (строки >160 символов — таблица сущностей), `UITypes.pas:992–994` (выравнивание столбцов), `Core.pas:~1700` (ассемблер).
- Рекурсивные/развёрнутые реализации в самих `Core`/`Strings`/`Conv`, которые *являются* реализацией вызовов, на которые предлагается заменять (`Bits.*`, `Color.Swap`, `Conv.EncodeHex`, `Strings8Helper.Add`) — в находки не включены.
- `Compress.pas`, `Crypto.pas`, `ADPCM.pas`, `LongMath.pas` (ассемблерные `bSqr` и т.п.): низкоуровневые алгоритмы; побитовые выражения там — суть алгоритма (кроме отмеченных в 3.5 мест).

## 6. Что осталось неохваченным и как продолжить

- Построчное чтение не выполнялось для: `Geom3D`, `Threads`, `HashMaps`, `ControlFiles`, `SCGI`, `Database`, `HtmlTree`, `Translation`, `FreeTypeFont`, `GlyphCache`, `Window`, `ResManGL`, `Sound`, `SoundSDL`, `UITypes`, `UIWidgets`, `UIScene`, `DefaultStyle` — в них возможны находки категории «сложное выражение»/«длинная процедура», не ловящиеся шаблонами.
  Предлагаю следующим шагом прочитать по очереди 5–6 самых крупных (Window, ResManGL, UITypes, UIWidgets, Game, Geom3D) и дополнить раздел 3.5–3.7.
- Для надёжной проверки неиспользуемых `uses`, приватных методов и публичных символов нужна компиляция (FPC `-vh`/`-Sew` покажет «unit not used» и «local variable not used») — в среде ревью компилятора нет.
- Все автоматические поиски воспроизводимы скриптами, которые остались в scratchpad (`pat.py`, `dup.py`, `dup2.py`, `scan3.py`).
