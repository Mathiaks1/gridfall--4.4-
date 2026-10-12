# Gridfall — Art Bible

Status: Krok 1 i 2 zaakceptowane. Krok 3 partia 1 (pola) gotowa i podpięta do gry. Czeka na akceptację.

## Narzędzia (zweryfikowane)
- Blender **3.5.0** (`E:\Blender\blender.exe`), EEVEE (legacy), Python 3.10 + numpy. Pillow niedostępny, więc PNG zapisujemy własnym kodem (`tools/pxlib.py`).
- Godot 4.7, renderer Mobile.

## Paleta — 32 kolory (`palette/`)
Jedyne źródło prawdy: `tools/palette_def.py`. Pliki `.png` / `.gpl` / `.hex` generuje `tools/export_palette.py` (część `build_all.py`).

| Rampa | Znak | Hex (ciemny → jasny) | Rola |
|---|---|---|---|
| stone | 0–8 | 0d0b14 1b1926 2a2738 3c3a4e 545266 767383 9e979b cbc0b0 f2e8d2 | tło, pola, UI, kości, tekst |
| earth | T–W | 3d241f 6b4030 a0684a e0a77c | drewno, skóra, ruda, cera |
| blood | A–D | 3b0f1e 74182a b82e35 f0583f | HP, krew, flaga, ogień |
| gold | E–H | 7a3a12 c06a1c f0a630 ffe17a | złoto, skarb, krytyk, awans |
| moss | I–L | 0f2e2b 1c5a3d 3f9346 9ad660 | szlam, trucizna, leczenie, EXP |
| frost | M–P | 132447 1d4f8f 3b94d6 8ee0f2 | wyjście, kryształ, zwoje |
| arcane | Q–S | 3a1d55 6e3a96 b56ad6 | magia, rzadkość |

- Najciemniejszy kolor `0d0b14` nie jest czystą czernią.
- Cienie przesunięte w stronę fioletu i granatu (np. cień czerwieni `3b0f1e` ciągnie do fioletu, cień zieleni `0f2e2b` do morskiego). Światła przesunięte w stronę żółci (`9ad660`, `ffe17a`, `f2e8d2`).
- 9 neutralnych kolorów, bo pola i UI zajmują około 70% ekranu i potrzebują pełnej rampy jasności. Akcenty mają po 3–4 stopnie.

## Zasady stylu
1. Rozmiar piksela jest jeden. Skalowanie wyłącznie całkowite, filtr Nearest, alfa 0/255. Kontrolują to `check_alpha_binary` i `check_in_palette` przy każdym zapisie.
2. Światło z lewej-góry. Krawędzie oświetlone (góra/lewo) są o 1 stopień rampy ciemniejsze od wypełnienia, krawędzie w cieniu o 2 stopnie (`selective_outline`). Kontur nigdy nie jest czarny. Wyjątek: oczy i cienie cyfr mogą używać `0`.
3. Pole zakryte jest wypukłe: jasna faza góra/lewo, ciemna dół/prawo, wypełnienie `3`. Pole odkryte jest wklęsłe: fazy odwrotne, wypełnienie `1`. W skali szarości różnica jest wyraźna (patrz `previews/style_board_x4_gray.png`).
4. Wszystkie zakryte pola używają jednego sprite'a `tile_hidden.png`. Nakładki dla treści nie istnieją, dopóki pole jest zakryte (zero przecieków).
5. Cyfry:
   - Wszystkie glify są pogrubione (kreska 2 px), z cieniem 1 px w prawo-dół.
   - Kolory: 1 `O` niebieski, 2 `L` limonka, 3 `D` czerwień, 4 `S` fiolet, 5 `G` złoto, 6 `P` lód, 7 `8` pergamin, 8 `6` szarość.
   - Główną cechą rozróżniającą jest kształt glifu. Kolory dobrano tak, żeby sąsiednie cyfry różniły się także jasnością.
   - Symulacja deuteranopii: najbliższa para to 2/5. Obie są żółtawe, ale różnią się jasnością i kształtem.
6. Stan „rozpatrzony” (pokonany potwór, zebrany skarb): **osobny sprite** z przemapowaniem na rampę `stone` (`pxlib.recolor`) zamiast półprzezroczystości. Obecny `TileSkin.resolved_alpha = 0.35` łamie regułę alfy 0/255 i trzeba go zastąpić.
7. Prawy-dolny róg nakładek i ikon (x ≥ 24, y ≥ 22) jest zarezerwowany na małą cyfrę narożną pól specjalnych. Nie umieszczamy tam iskier ani detali.
8. Sylwetka musi być czytelna przy 1×, na tle `1` (odkryte pole) i `0` (tło gry).

## Ścieżki produkcji
| Kategoria | Ścieżka | Dlaczego |
|---|---|---|
| Pola, cyfry, nakładki, flaga, UI (ramki 9-slice, paski, przyciski), ikony atrybutów, czcionka | **B** (mapy ASCII / generator w Pythonie) | Geometria 1 px musi być idealna. Render 3D dałby tu tylko szum. Mapy ASCII są w gicie i diffowalne, a paleta podmienia się automatycznie. |
| Ikony przedmiotów i surowców (16/32 px) | **B** | Przy tej wielkości ręczny piksel jest czytelniejszy niż render. |
| Portrety bojowe potworów, bohater, NPC (z animacjami) | **A** (Blender, toon: Shader to RGB, rampa CONSTANT, emisja; 1 próbka TAA, filtr 0 px) | Spójna bryła, światło i klatki animacji z jednego modelu. Warianty kolorystyczne dla głębszych pięter to podmiana rampy w materiale albo `recolor` po renderze. |
| Ikony potworów na polu | **B**, rysowane na podstawie sylwetki z renderu A | Render zmniejszony do rozmiaru pola gubi kształt. |
| VFX | **B** (generator klatek) + ręczne poprawki | Kształty proste, liczy się timing. |
| Tła | **A** (prosta scena lochu) + kwantyzacja | Głębia i perspektywa za darmo. |



## Decyzje i założenia
- **D1 (rozstrzygnięte: B):** komórka **32 px**, logiczna rozdzielczość 640×360, plansza do **16×10** rosnąca w poziomie. Ikony przedmiotów, surowców i potworów na polu: 32×32. Sprite'y bojowe i portrety: 64×64. Zmiana `max_width/max_height` w `floor_config` należy do kodu gry.
- Z1: logiczna rozdzielczość **640×360**, `stretch/mode = viewport`, `stretch/scale_mode = integer`, `aspect = expand`. Skale: 1280×720 = 2×, 1920×1080 = 3×, 2560×1440 = 4×. Na telefonach 20:9 dodatkowa szerokość trafia do HUD. *(Do sprawdzenia w edytorze 4.7, czy opcja `scale_mode` ma tę nazwę.)*
- Z2: widok. Ikony na polach pokazujemy od frontu. Sprite'y bojowe w 3/4: bohater po lewej patrzy w prawo, potwory po prawej patrzą w lewo. Kamera Blendera stała: obrót 30°, pochylenie 20°.
- Z3: potwory. **Gotowe:** szlam, szkielet, ghul (idle 64×64 + ikona 32×32). Ikony humanoidów to popiersia kadrowane od czubka głowy (`"anchor": "top"`), bo pełna postać w 32 px gubi kończyny. **W planie:** szczur, goblin, ork (są w `data/monsters/`), upiór, plus warianty kolorystyczne „elitarne” na głębsze piętra przez podmianę rampy. Ghula nie ma jeszcze w danych gry (`MonsterData`).
- Z4: broń to miecz w 4 tierach (żelazny, stalowy, runiczny, smoczy), a zbroja to napierśnik w 4 tierach. Tier rozpoznaje się po materiale (rampa) i rosnącej złożoności sylwetki.
- Z5: ulepszenia Kowala (+1, +2…) nie zmieniają sprite'a. Godot nakłada plakietkę „+N” z czcionki bitmapowej.
- Z6: czcionka będzie własna, bitmapowa, z polskimi znakami (ąćęłńóśźż), bo UI jest po polsku. Import przez Godot „Image Font”. Licencja: nasza (CC0 albo dowolna, do ustalenia).
- Z7: folder docelowy. W projekcie istnieje `Assets/` (z wielkiej litery, ze starymi placeholderami). Windows nie rozróżnia wielkości liter, ale eksport na Androida i do .pck tak. W Kroku 2 nazwa została zmieniona na `assets/` (`git mv`, nic się do niego nie odwoływało). Obowiązuje `res://assets/art/...`.
- Z8: `grid_manager.gd` liczy `_tile_size` jako `floor(fit)` z zakresu 4–72 px, czyli skalowanie niecałkowite. Trzeba to zmienić na całkowite wielokrotności (zakres prac w kodzie, poza grafiką).

## Pipeline — jak używać

```
E:\Blender\3.5\python\bin\python.exe art_src\build_all.py            # wszystko (~15 s)
E:\Blender\3.5\python\bin\python.exe art_src\build_all.py --skip-3d  # tylko ścieżka B + podglądy
```

| Plik | Rola |
|---|---|
| `tools/palette_def.py` | paleta (jedyne źródło prawdy) |
| `tools/config.py` | rozmiary (CELL, ICON, PORTRAIT), gęstość pikseli renderów, ścieżki wyjściowe |
| `tools/pxlib.py` | PNG I/O, mapy ASCII, kwantyzacja OKLab, kontur selektywny, linie wewnętrzne, testy |
| `tools/sheet.py` | sprite sheety (poziomy pasek, jednakowa komórka) + JSON |
| `blender/build_template.py` | buduje `gridfall_template.blend` (kamera, słońce, render, kolekcje) |
| `blender/bl_common.py` | materiały toon spięte z paletą, kadrowanie, przebieg ID |
| `blender/models/*.py` | modele (`build`) i pozy klatek (`pose`) w pełnych pikselach |
| `blender/manifest_3d.py` | lista assetów ścieżki A i ich wyjść |
| `blender/render_batch.py` | render → kwantyzacja → linie wewnętrzne → kontur → PNG/sheet |
| `pixel/pixel_assets.py` | assety ścieżki B (rejestr `@asset`) |
| `tools/pilot_preview.py` | contact sheet 1×/3×/8×, siatka 8×8, makieta ekranu 640×360 |

Zasady renderu (ścieżka A, Blender 3.5):
- EEVEE, Filter Size 0, 1 próbka TAA, Film Transparent, Standard/None.
- Słońce o mocy π bez cieni i bez otoczenia, więc Shader to RGB daje cos kąta.
- Rampa CONSTANT emituje dokładnie kolory palety.
- Kamera ortho z elewacją 25°. Bohater obrócony +35° (patrzy w prawo), potwory −35°.
- Gęstość pikseli jest wspólna dla portretów (0,04 j./px), więc wielkości potworów są spójne między sobą.
- Animacje: przesunięcia liczone w pełnych pikselach (`px_z`). Kadr liczony raz z pozy spoczynkowej, dzięki czemu wszystkie klatki mają wspólną linię gruntu.
- Drobne elementy (oczy) tylko się przesuwają, bez skalowania, żeby nie migotały.

## Import do Godota 4.7
- Filtr: projekt ma już `rendering/textures/canvas_textures/default_texture_filter = Nearest`.
- Domyślny import tekstur w tym projekcie (sprawdzone w `.import`): `compress/mode=0` (Lossless), `mipmaps/generate=false`. Nic nie trzeba zmieniać.
- Sprite sheety: `AnimatedSprite2D` + `SpriteFrames` (klatki z atlasu wg JSON) albo `Sprite2D` z `hframes = frames`.
- 9-slice: `NinePatchRect`, `patch_margin_*` z pliku `ui_panel.json`.
- Do zrobienia w kodzie gry: `display/window/stretch/mode = viewport`, `display/window/stretch/scale_mode = integer`, rozdzielczość 640×360, rozmiar pola = 32 px × skala całkowita.

## Integracja z grą (stan po partii 1)
- `data/default_tile_skin.tres`: wszystkie tekstury pól, cyfry 1–8, małe cyfry narożne, stany rozpatrzone, pole po wybuchu, błędna flaga, animacja odkrycia (4 klatki, 20 fps).
- `Tile.set_icon()` + `GridManager.icon_resolver` (podaje `game.gd`): ikona konkretnego potwora (`MonsterData.texture`) i surowca (`CraftingMaterial.icon`) na polu. Bez ikony rysowana jest ikona ogólna ze skina albo placeholder.
- `GridManager.art_tile_size = 32`: pole na ekranie ma rozmiar 32 × k (k całkowite). Awaryjnie skala ułamkowa, gdy brakuje miejsca nawet na 32 px.
- `MonsterData.battle_sheet / battle_frames / battle_fps` + `BattleSprite` (scenes/ui/battle_sprite.gd): animowane portrety na ekranie walki, skala 2×.
- Nowe potwory w danych: `slime` (piętro 1+), `ghoul` (piętro 4+), dopisane na końcu listy w `game_database.tres`, więc indeksy w zapisach się nie zmieniają.
- Podgląd w prawdziwej grze: `godot --path . res://tests/CaptureScreens.tscn` → `art_src/previews/ingame_*.png`.
- Nie podpięte (brak obsługi w kodzie): `overlay_hover`, `overlay_select`.
