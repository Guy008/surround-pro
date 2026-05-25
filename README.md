# surround-pro

Convert any media (YouTube URL / local audio / video) into a single MKV with **5 audio formats** (7.1 / 5.1 / 2.1 / Stereo / Mono), using AI source separation.
המרת כל קובץ מדיה ל-MKV יחיד עם 5 פורמטי שמע (7.1 / 5.1 / 2.1 / Stereo / Mono) באמצעות הפרדת מקור בעזרת AI.

> **Latest version:** v1.0 — Docker container available + native Arch/Debian/Ubuntu/Fedora support + search by song name.

---

## 🚀 Quickstart (Docker — easiest, all OSes)

```bash
git clone https://github.com/Guy008/surround-pro.git
cd surround-pro
docker compose build               # one-time, ~2 min
docker compose run --rm surround-pro "Hadag Nahash Ringing Slap"
# Output in ./output/<title>_surround.mkv
```

Open the result in **mpv** or **VLC**, switch audio tracks to pick your format (7.1 / 5.1 / 2.1 / Stereo / Mono).

---

## 🎯 What it does

Single command takes any of:
- YouTube URL: `./surround-pro.sh "https://..."`
- Local file: `./surround-pro.sh /path/to/song.mp3`
- Folder (batch): `./surround-pro.sh /path/to/folder/`
- Song name (auto-searches YouTube): `./surround-pro.sh "Hadag Nahash Ringing Slap"`

Produces a single MKV with original video (if any) + 5 audio tracks at different surround formats. AI pipeline does instrument-aware separation so different instruments end up in different speakers.

---

## מה זה עושה

מקבל אחד מאלה:
- **URL** (YouTube וכו')
- **קובץ מקומי** (mp3/mp4/mkv/wav/וכו')
- **תיקייה** (batch — כל הקבצים בתוכה)
- **שם שיר** — יוחפש ביוטיוב אוטומטית

ומפיק קובץ **MKV יחיד** (`*_surround.mkv`) שמכיל:
- וידאו מקורי (אם הקלט וידאו)
- **חמישה פסי שמע FLAC**: 7.1 / 5.1 / 2.1 / Stereo / Mono — המשתמש בוחר ב-player

הפרדה משולשת מבטיחה איכות ערוצים: הזמר מבודד מהמוזיקה, ה-echo/reverb מבודד מהזמר היבש, וכל אחד הולך למקום המתאים שלו ב-7.1.

---

## דרישות

**הסקריפט מתקין הכל לבד** — לא חייב להתקין שום דבר ידנית. הסקריפט יזהה מה חסר ויתקין דרך `pacman` (סודו ייבקש את הסיסמא פעם אחת).

נדרשים בסיסיים שצריכים להיות כבר על המערכת:
- Arch Linux (התמיכה במערכות אחרות תיווסף בעתיד)
- `bash`, `sudo`
- חיבור לאינטרנט (להורדת חבילות + מודלים בריצה ראשונה)
- דפדפן: Chrome / Chromium / Firefox / Brave / Vivaldi / Opera (לעוגיות YouTube)

הסקריפט מתקין אוטומטית:
- `uv`, `yt-dlp`, `ffmpeg`/`ffprobe`
- `rocm-hip-runtime` + `patchelf` + `binutils` (רק אם זוהה AMD GPU)
- חבילות Python: `torch` (CUDA/ROCm/CPU לפי החומרה), `demucs`, `audio-separator`, `onnxruntime`

---

## הפעלה

### 🐳 Docker (הכי קל — Windows / Mac / Linux)

```bash
# פעם ראשונה: בניית ה-image (לוקח 1-2 דקות)
docker compose build

# הפעלה (מצב CPU — ללא GPU):
docker compose run --rm surround-pro "Hadag Nahash Ringing Slap"
docker compose run --rm surround-pro "https://www.youtube.com/watch?v=..."

# הפלט נשמר בתיקיית output/ ליד ה-compose file
```

ה-Docker image מבוסס Ubuntu 24.04 + כל התלויות מובנות בו. כל המודלים יורדים פעם אחת ונשמרים ב-Docker volume (`surround-pro-models`) — שורדים reboot, ריצות עתידיות מהירות.

---

### 🖥️ ריצה ישירה ב-Arch Linux (מהיר יותר עם GPU)

#### מצב אינטראקטיבי

```bash
./surround-pro.sh
```

הסקריפט ישאל להזין URL / קובץ / תיקייה.

### עם ארגומנט ישיר

```bash
./surround-pro.sh "https://www.youtube.com/watch?v=..."
./surround-pro.sh /path/to/song.mp3
./surround-pro.sh /path/to/folder/        # מעבד את כל הקבצים בתיקייה
./surround-pro.sh "Hadag Nahash Ringing Slap"   # חיפוש לפי שם שיר
```

### עזרה ופרטים

```bash
./surround-pro.sh --help
```

### שינוי דפדפן לעוגיות

הסקריפט מזהה אוטומטית את הדפדפן הראשון שמותקן (chrome → chromium → brave → firefox → vivaldi → opera). לשליטה ידנית:

```bash
BROWSER_FOR_COOKIES=firefox ./surround-pro.sh https://...
```

### שינוי מיקום קאש מודלים

מודלי audio-separator נשמרים ב-`~/.cache/audio-separator-models/` (שורד reboot). לשינוי:

```bash
AUDIO_SEPARATOR_MODEL_DIR=/path/to/cache ./surround-pro.sh ...
```

---

## מבנה הפרויקט

```
surround-pro/
├── surround-pro.sh         # entry point
├── lib/
│   ├── install-deps.sh     # התקנה אוטומטית של pacman packages + patchelf
│   ├── detect-hardware.sh  # זיהוי GPU + פונקציות עזר
│   ├── setup-env.sh        # GPU compute test + הורדת torch + מודל Demucs
│   ├── handle-input.sh     # URL / קובץ / וידאו / שמע
│   ├── separate-stems.sh   # 3-stage: BS-RoFormer + De-Echo + Demucs
│   ├── build-71.sh         # ffmpeg filter_complex ל-7.1
│   └── cleanup.sh          # תיקיות זמניות + unique filenames
├── docs/
│   └── DECISION_LOG.md     # יומן החלטות תכנון
├── input/                  # קבצי קלט (gitignored)
├── output/                 # קבצי פלט (gitignored)
├── README.md
└── CHANGELOG.md
```

---

## הפייפליין (5 שלבים)

1. **סריקת חומרה + הכנה** — זיהוי GPU (NVIDIA / AMD ROCm / Intel / CPU). התקנה אוטומטית של תלויות חסרות. בדיקת GPU compute אמיתית (לא רק `cuda.is_available()`). באמצעות `patchelf --clear-execstack` ו-`HSA_OVERRIDE_GFX_VERSION` לתאימות AMD רחבה.
2. **זיהוי קלט וטעינה** — URL ⇒ yt-dlp / קובץ מקומי ⇒ cp + ffmpeg extract.
3. **הפרדה משולשת:**
   1. **BS-RoFormer Vocals** (audio-separator) ⇒ `vocal_wet.wav` + `instrumental.wav` — מבודד את הזמר עם כל ה-effects שלו מהמוזיקה.
   2. **UVR-DeEcho-DeReverb** ⇒ `dry_vocal.wav` + `echo_tail.wav` — מבודד את ה-echo/reverb של הזמר בנפרד מהזמר היבש.
   3. **Demucs htdemucs_ft** עם `--shifts 4` (GPU) או `1` (CPU) ⇒ `drums.wav`, `bass.wav`, `other.wav` (כולם נקיים לחלוטין מזמר).
4. **מיפוי 7.1 + קידוד FLAC** (ffmpeg filter_complex).
5. **קובץ סופי + ניקוי** של תיקיות זמניות.

---

## מיפוי ערוצי 7.1 (v0.2)

| ערוץ | תוכן |
|------|------|
| **FL/FR** | Drums highpass >100Hz (cymbals + snare/tom body) + echo_tail × 0.4 (-8dB) |
| **FC** | **Dry vocal** — זמר ממוקד ויבש, ללא echo — *נעול בלבד ב-FC* |
| **LFE** | Drums lowpass <120Hz (kick) + Bass mono |
| **SL/SR** | **Piano** + other × 0.3 (fill עדין) |
| **BL/BR** | **Guitar** + other × 0.7 (רוב ה-synths/ambient) |

> **למה ה-echo ב-FL/FR?** ה-echo/reverb של הזמר אמור להתפזר רחב במרחב — בדיוק כפי שהמהנדס המקורי התכוון. ה-FC נשמר נקי ויבש, וה-echo מקבל את ה"רוחב" שלו ברמקולים הקדמיים.

> **למה piano בצדדים וגיטרה אחורה?** העדפה אמנותית — piano יוצר נוכחות חזקה בצדדים, גיטרה+ambient נותנים עומק/אווירה אחורה. ה-"other" (synths, strings) מתפצל 30% לצדדים / 70% לאחור — מבטיח שלא יישארו ערוצים שותקים אם השיר חסר piano/guitar.

---

## תמיכה ב-GPU (תאימות אוטומטית רחבה)

| GPU | Backend | אוטומציה |
|-----|---------|----------|
| NVIDIA | CUDA (cu121) | Native — torch+cu121 פשוט עובד |
| AMD RDNA2 (RX 6800/6900, gfx1030) | ROCm 6.0 | `patchelf --clear-execstack` אוטומטי |
| AMD RDNA2 (RX 6600/6700, gfx1031/1032) | ROCm 6.0 + override | `patchelf` + `HSA_OVERRIDE_GFX_VERSION=10.3.0` אוטומטי |
| AMD אחר | ROCm 6.0 | ניסיון GPU; אם נכשל ⇒ CPU fallback אוטומטי |
| Intel | xpu | בסיסי (לא נבדק עדיין) |
| ללא GPU | CPU | עובד, איטי יותר |

---

## תמיכה בעברית ושמות בעייתיים

- שמות קבצים עם **תווים בעברית** עוברים כפי שהם.
- תווים אסורים במערכת קבצים (`/ \ ? % * : | " < >`) מומרים ל-`_`.
- אם קובץ פלט באותו שם כבר קיים → נוסף סיומת `_1`, `_2`, וכו' (ללא דריסה).

---

## מצב פיתוח

זוהי גרסה v0.1 — איכות מספיקה, מבנה יציב, חוסר תכונות מתקדמות. תכונות מתוכננות לעתיד:

- שיפור AI אופציונלי (AudioSR + Resemble Enhance)
- Re-encoding וידאו עם GPU (nvenc/amf/qsv)
- Docker (אופציונלי)
- אוטו-התקנה גם ב-Debian/Ubuntu (apt) ו-Fedora (dnf)
- מודלי Demucs / audio-separator שניתן להחליף דרך משתנה סביבה
