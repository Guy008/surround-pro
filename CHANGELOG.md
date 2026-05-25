# Changelog

כל השינויים המהותיים בפרויקט מתועדים בקובץ זה.

הפורמט מבוסס על [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
והפרויקט מקפיד על [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] — 2026-05-25

🎉 **שחרור ציבורי ראשון.** הפרויקט מוכן למשתמש קצה: מתקין הכל לבד, רץ בכל מערכת הפעלה (Linux+Docker), ומפיק קובץ אחד עם כל פורמטי השמע.

### Added — שחרור גרסה ראשונה

- **Multi-OS native auto-install** — `lib/install-deps.sh` עכשיו תומך ב-`pacman` / `apt` / `dnf` / `zypper`. משתמשי Debian/Ubuntu/Fedora מקבלים אוטו-התקנה של ffmpeg + yt-dlp (דרך pip לגרסה עדכנית) + patchelf + binutils.
- **LICENSE — MIT** (Copyright 2026 Guy Levi). פירוט גם על רישיונות הספריות החיצוניות שהפרויקט משלב.
- **README דו-לשוני** (אנגלית + עברית) עם quickstart ל-Docker בראש.

### Changed

- שם הגרסה ב-`surround-pro.sh` ו-`--help` — `v0.3` → `v1.0`.

### Limitations

- **AI source enhancement** (AudioSR / Resemble Enhance) — לא נכלל. ייתכן בגרסה עתידית כדגל אופציונלי.
- **AMD GPU ב-Docker** — לא נכלל. דורש image variant נפרד עם ROCm. אפשרי לעתיד.
- **NVIDIA GPU ב-Docker** — דורש flag `--gpus all` ידני (לא נסיון בהדגמה). אפשרי לעתיד.
- **WebUI / hosted version** — post-v1.0.

### Tested

- ✅ AMD RX 6700 XT (Arch + ROCm + HSA_OVERRIDE) — 6 שירים end-to-end
- ✅ NVIDIA RTX 2060 (Arch + CUDA) — 4 שירים end-to-end
- ✅ Docker (Ubuntu 24.04 base, CPU mode) — שיר אחד end-to-end
- ✅ Multi-format MKV output — 5 streams נכונים על כל הריצות
- ✅ Cleanup robust — אין דליפת work dirs
- ✅ AMD GPU compute auto-fix — patchelf + HSA_OVERRIDE_GFX_VERSION עובד אוטומטית
- ✅ CPU fallback אם GPU נכשל
- ✅ Search by name — מצא את ה-URL הנכון לפי שם שיר

---

## [0.4.0] — 2026-05-25

הצעד הגדול להנגשה: **Docker container רשמי**. כל משתמש בעולם עם Docker יכול עכשיו להריץ את הפייפליין בלי להתקין שום דבר (פרט ל-Docker עצמו).

### Added

- **`Dockerfile`** — Ubuntu 24.04 base. מכיל את כל התלויות:
  - bash, ffmpeg, build-essential, python3-dev (ל-compilation של diffq)
  - yt-dlp דרך pip (גרסה אחרונה — apt's old, נחסם ע"י YouTube)
  - patchelf + binutils (לעתיד, אם נוסיף GPU AMD ב-Docker)
  - uv (התקנה user-local, ואז ל-/usr/local/bin)
- **`docker-compose.yml`** — מוכן לשימוש, mounts ל-input/output + named volume למודלים שורד reboot.
- **README** עם הוראות Docker (הופך לדרך המומלצת לרוב המשתמשים).

### Notes & Trade-offs

- ה-Docker רץ ב-**CPU mode** בלבד כרגע. למשתמשי GPU NVIDIA: יש אופציה להוסיף `--gpus all` ידנית. AMD ROCm ב-Docker = work in progress.
- **כל הריצה הראשונה** מורידה ~3GB (torch CPU + audio-separator + מודלי AI). הריצות אחר כך מהירות (cache).
- **YouTube cookies:** אין דפדפן ב-Docker. שירים פתוחים יורדים. שירים מוגבלים-גיל / region-locked עלולים להיכשל — פתרון עתידי: mount של cookies.txt.

### Internal Refactor

- `OUTPUT_DIR` הוא עכשיו override-able דרך env var (`$SCRIPT_DIR/output` בברירת מחדל). Docker יכול לכוון ל-`/output` ללא sed magic.

### Validated

- Docker build successful (Ubuntu 24.04 base, ~500MB image)
- End-to-end pipeline test (5_dpyRWYo_g): MKV עם 6 streams (av1|flac/7.1|flac/5.1|flac/2.1|flac/stereo|flac/mono) ✓
- CPU mode runs ~15-20 min על שיר של 4 דק' (vs ~5 דק' עם GPU native)

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
