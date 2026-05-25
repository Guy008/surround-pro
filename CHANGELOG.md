# Changelog

כל השינויים המהותיים בפרויקט מתועדים בקובץ זה.

הפורמט מבוסס על [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
והפרויקט מקפיד על [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.3.0] — 2026-05-25

הקובץ הסופי הוא MKV אחד עם **5 פורמטים שמע** שהמשתמש בוחר ב-player. גם חיפוש ביוטיוב לפי שם שיר (ללא URL).

### Added

- **Multi-format MKV output** — קובץ סופי יחיד `*_surround.mkv` עם 5 פסי שמע:
  1. **7.1 Surround** (default — מי שאין לו רמקולים זה מה שיש)
  2. **5.1 Surround** (side layout)
  3. **2.1** (Stereo + LFE)
  4. **Stereo**
  5. **Mono**
  - כל אחד כ-FLAC 48kHz/16-bit ללא דחיסה
  - כותרות מטא ב-MKV — `mpv`/`VLC` מאפשרים לבחור בטעינה
- **Search-by-name** — אם הקלט אינו URL/קובץ/תיקייה, הסקריפט מחפש ב-YouTube אוטומטית ומוריד את התוצאה הראשונה:
  ```bash
  ./surround-pro.sh "Hadag Nahash The Ringing Slap"
  ```
- **Help section** מעודכן עם הפיצ'ר החדש.

### Changed

- שם הקובץ הסופי: `*_7.1.mkv` → `*_surround.mkv` (יותר מדויק — מכיל הכל).
- `build_71_audio` + `mux_video_with_71_audio` הוחלפו ב-`build_multi_format_output` שעושה הכל ב-pass יחיד של ffmpeg.

### Validated

- AMD RX 6700 XT: search "Hadag Nahash" → MKV עם 5 streams (`h264|flac/7.1|flac/5.1|flac/2.1|flac/stereo|flac/mono`) ✓

---

## [0.2.0] — 2026-05-25

הרחבת ההפרדה לרמת כלים בודדים + מיפוי 7.1 חכם יותר.

### Changed — Pipeline

- **Demucs htdemucs_ft → htdemucs_6s** — 6 stems במקום 4: vocals, drums, bass, **guitar**, **piano**, other.
- **מיפוי 7.1 חדש** מנצל את ה-stems החדשים:
  - **FC** = dry vocal (ללא echo, ממורכז) — *נעול בלבד ב-FC, לא בשום מקום אחר*
  - **FL/FR** = drums highpass>100Hz (cymbals + body) + echo_tail × 0.4 (-8dB)
  - **LFE** = drums lowpass<120Hz (kick) + bass mono
  - **SL/SR** = **piano** + other × 0.3 (fill עדין לערוצים בלי פסנתר)
  - **BL/BR** = **guitar** + other × 0.7 (רוב ה-ambient/synths)
- **ffmpeg filter_complex** — 7 inputs (היה 5). `asplit` של "other" כדי לפצל ל-sides/back.

### Changed — Filter tweaks

- **drums highpass: 250Hz → 100Hz** — כדי שגם snare body + tom body יגיעו ל-FL/FR (לא רק מצילות).
- **echo weight ב-FL/FR: 1.0 → 0.4** — ה-echo כבר לא מאסטר על התופים.

### Trade-offs

- htdemucs_6s SDR נמוך מ-_ft (8.5/10.1 vs 10.0/12.0 ל-drums/bass). הפרדה קצת פחות נקייה בתמורה ל-guitar+piano בנפרד.
- piano stem ידוע bleeding/artifacts (לפי Meta) — בשירים בלי פסנתר, ערוצי SL/SR עלולים לקבל "פסולת" קלה.
- htdemucs_6s = single model (לא bag of 4 כמו _ft) — **מהיר יותר** מ-v0.1.

### Tested

- AMD RX 6700 XT — v0.2 גועגועים ✓
- (more validation in progress)

ראשון. הוטמע ונבדק end-to-end על שתי חומרות שונות (AMD RX 6700 XT, NVIDIA RTX 2060).

### Added — תשתית הפרויקט

- **`surround-pro.sh`** — entry point ראשי. TUI. תומך URL / קובץ / תיקייה. אותו flow לכל סוגי הקלט.
- **`lib/install-deps.sh`** — התקנה אוטומטית של תלויות חסרות (uv, yt-dlp, ffmpeg, rocm-hip-runtime, patchelf, binutils) דרך `pacman`.
- **`lib/detect-hardware.sh`** — זיהוי GPU (NVIDIA / AMD ROCm / Intel / CPU), בחירת `torch index URL` ו-`Demucs device`. זיהוי דפדפן ל-cookies (chrome → chromium → brave → firefox → vivaldi → opera).
- **`lib/setup-env.sh`** — בדיקת GPU compute אמיתית (לא רק `cuda.is_available()`). Fallback אוטומטי `patchelf → HSA_OVERRIDE → CPU`. הורדת מודל htdemucs_ft.
- **`lib/handle-input.sh`** — `yt-dlp` עם cookies מהדפדפן (auto-detect), העתקה של קובץ מקומי, חילוץ אודיו ב-48kHz סטריאו.
- **`lib/separate-stems.sh`** — Pipeline משולש:
  1. `audio-separator` עם `model_bs_roformer_ep_368_sdr_12.9628.ckpt` ⇒ vocals + instrumental
  2. `audio-separator` עם `UVR-DeEcho-DeReverb.pth` ⇒ dry_vocal + echo_tail
  3. `demucs htdemucs_ft` עם `--shifts 4` ב-GPU / `1` ב-CPU על ה-instrumental ⇒ drums + bass + other
- **`lib/build-71.sh`** — `ffmpeg filter_complex` למיפוי 7.1 עם echo_tail מעורבב ל-FL/FR.
- **`lib/cleanup.sh`** — מחיקת תיקיות עבודה, יצירת שם פלט ייחודי (מניעת דריסה).
- **README.md** + **docs/DECISION_LOG.md** — תיעוד.

### Features — תכונות

- תמיכה בשמות קבצים בעברית ובתווים מיוחדים.
- תמיכה ב-batch של תיקייה שלמה.
- **התקנה אוטומטית** של תלויות חסרות (uv, ffmpeg, yt-dlp, ROCm runtime).
- **GPU compute test אמיתי** — לא בוטח ב-`cuda.is_available()` עד שלא מבצע operation בפועל.
- **AMD GPU compatibility** — auto-fix של execstack issue ב-PyTorch+ROCm libs (`libamdhip64.so`, `libhiprtc.so`).
- **HSA_OVERRIDE_GFX_VERSION=10.3.0** auto-detection — תמיכה ב-RDNA2 GPUs (RX 6600/6700 family) שלא מקבלים kernels מקומפילים.
- **CPU fallback אוטומטי** אם GPU נכשל בכל הניסיונות.
- **Auto-detect דפדפן** ל-yt-dlp cookies — מתאים את עצמו למה שיש על המערכת.
- `--cookies-from-browser` ל-yt-dlp (עקיפת bot detection של YouTube).
- שם פלט ייחודי — אין דריסת קבצים קיימים (`_1`, `_2`, וכו').
- ניקוי מלא של תיקיות עבודה זמניות בסוף כל ריצה.

### Audio Pipeline — איכות הפרדה

לעומת גרסת prototype ישנה (`htdemucs` בסיסי, single-pass):

- **htdemucs_ft** במקום htdemucs — bag of 4 models, SOTA quality.
- **BS-RoFormer Vocals** *לפני* Demucs — מודל ייעודי לזמר שמטפל ב-effects (echo, reverb) הרבה יותר טוב.
- **De-Echo Step** — מבודד את ה-echo של הזמר ומנתב אותו ל-FL/FR (שדה רחב), כשה-dry vocal הולך ל-FC (ממורכז).

תוצאה: ה-rear speakers (BL/BR) ו-side speakers (SL/SR) כמעט נקיים לגמרי מ-bleed של זמר, וה-FC ברור ויבש.

### Tested Hardware

| Machine | GPU | Backend | Outcome |
|---------|-----|---------|---------|
| Guy008MC | AMD RX 6700 XT | ROCm + patchelf + HSA_OVERRIDE | ✓ |
| Guy008PC | NVIDIA RTX 2060 | CUDA native | ✓ |

### Quality-of-life

- **`--help`** / **`-h`** מציג usage ויוצא.
- **OS detection** ב-stage 1 — אם לא Arch, מתפרסם warning עם רשימת תלויות שצריך להתקין ידנית, הסקריפט ממשיך.
- **Persistent audio-separator models** ב-`~/.cache/audio-separator-models/` (ניתן ל-override דרך `AUDIO_SEPARATOR_MODEL_DIR`). שורד reboot.

### Known Limitations

- ONNXRuntime עובד ב-CPU (BS-RoFormer onnx layer) — לא משפיע משמעותית.
- Intel GPU (xpu) — לא נבדק.
- אוטו-התקנה רק ב-Arch (pacman). מערכות אחרות עובדות אם הכלים מותקנים ידנית.
- אין תמיכה במודלים מותאמים אישית של Demucs / audio-separator (יבוא ב-v0.2+).
