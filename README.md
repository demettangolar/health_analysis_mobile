# Health Analysis Mobile

A Flutter mobile app that records **IMU (accelerometer + gyroscope)** data and
optionally **microphone audio** from your smartphone, and a companion Jupyter
notebook that derives **heart rate** and **breathing rate** from the collected
data.

---

## Repository structure

```
.
├── health_monitor/          # Flutter app
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   │   └── imu_sample.dart
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   └── recording_screen.dart
│   │   ├── services/
│   │   │   ├── sensor_service.dart      # accelerometer + gyroscope
│   │   │   ├── audio_service.dart       # microphone (bonus)
│   │   │   └── csv_export_service.dart  # CSV/M4A file management
│   │   └── widgets/
│   │       ├── timer_widget.dart
│   │       └── sensor_display.dart
│   ├── android/app/src/main/AndroidManifest.xml
│   └── ios/Runner/Info.plist
└── analysis/
    ├── health_analysis.ipynb  # Data-analysis notebook
    └── requirements.txt
```

---

## Part I – Flutter app

### Features

| Feature | Details |
|---|---|
| IMU recording | Accelerometer + Gyroscope at ~100 Hz via `sensors_plus` |
| Microphone (bonus) | AAC/M4A audio at 44.1 kHz mono via `record` |
| 5-minute countdown timer | Visual progress bar with colour-coded urgency |
| 3-trial management | Home screen tracks progress through all three trials |
| CSV export | `imu_trial_<n>_<timestamp>.csv` in app documents directory |
| File sharing | Native share sheet to AirDrop / email / Files |
| Screen wake-lock | Keeps display on during recording via `wakelock_plus` |

### Setup

1. Install Flutter ≥ 3.0: https://flutter.dev/docs/get-started/install
2. `cd health_monitor`
3. `flutter pub get`
4. Connect your device and run: `flutter run`

### Permissions required

| Permission | Platform | Purpose |
|---|---|---|
| `RECORD_AUDIO` / `NSMicrophoneUsageDescription` | Android / iOS | Bonus audio recording |
| `NSMotionUsageDescription` | iOS | Access accelerometer & gyroscope |
| `WAKE_LOCK` | Android | Keep screen on |

---

## Part II – Data collection protocol

1. Lie down or sit still in a quiet environment.
2. Place the phone **flat on your chest**, screen facing up.
3. Open the app → press **Start Trial**.
4. Remain as still as possible for the full **5 minutes**.
5. Repeat for a total of **3 trials**.
6. Use **Share All** to export `imu_trial_*.csv` (and `audio_trial_*.m4a`) to your computer.

---

## Part III – Data analysis

Open `analysis/health_analysis.ipynb` in JupyterLab or Google Colab.

### Method

The phone's **Z-axis accelerometer** (perpendicular to the chest wall when
lying flat) captures two superimposed signals:

| Signal | Frequency band | Mechanism |
|---|---|---|
| Breathing | 0.1 – 0.6 Hz (6 – 36 br/min) | Chest-wall expansion / contraction |
| Heartbeat (BCG) | 0.8 – 3.0 Hz (48 – 180 bpm) | Ballistic recoil from each cardiac ejection |

**Processing pipeline:**

```
raw acc_z
  └─ remove DC (subtract mean)
       ├─ bandpass 0.1–0.6 Hz  → breathing signal → peak detection → BR
       └─ bandpass 0.8–3.0 Hz  → BCG signal       → peak detection → HR
```

Both a **peak-detection** method and a **Welch PSD** method are used; their
results are reported side-by-side for cross-validation.

### Quick start

```bash
cd analysis
pip install -r requirements.txt
jupyter notebook health_analysis.ipynb
```

Edit the `CSV_FILES` list in cell 3 to point at your trial files, then
**Run All**.

---

## Bonus – Microphone analysis

When microphone recording is enabled in the app, an `audio_trial_*.m4a` file
is created alongside the CSV.  Cell 7 of the notebook computes the RMS
envelope of the audio and applies the same bandpass + peak-detection pipeline
to estimate breathing rate and heart rate from sound.

Install the optional dependency to enable this:

```bash
pip install librosa soundfile
```