# PoseCount 🏋️‍♂️🤖

PoseCount is an AI-powered, real-time push-up tracking mobile application built using **Flutter** and **Google MediaPipe / ML Kit Pose Detection**. By leveraging the device's native camera stream and mobile computer vision, the app maps a structural skeleton outline directly over the user's body to analyze posture and count repetitions accurately with high-precision vector mathematics.

---

## ✨ Features

* **Real-Time Pose Estimation:** Seamlessly tracks 33 human body landmarks at high frame rates utilizing Google's ML Kit Pose Detection API.
* **Live Structural Outline (Skeleton):** Overlays custom-painted lines and joint dots on top of the live camera preview feed so users receive immediate visual verification of tracking alignment.
* **Precise Algorithmic Counting:** Eliminates false-positives by monitoring exact elbow joint vectors through an explicit state-machine cycle.
* **Responsive State UI:** Displays a bold, highly scannable counter overlay accompanied by a real-time tracking pill indicating current state motion (`LOWER BODY` vs. `PUSH UP`).

---

## 🛠️ Tech Stack & Dependencies

* **Framework:** Flutter (Dart)
* **Computer Vision:** `google_mlkit_pose_detection` (or `mediapipe_flutter`)
* **Hardware Interface:** `camera` (Real-time image stream acquisition)
* **State Management:** `provider` (or native state hooks for clean data updates)

---

## 📐 How the Counting Logic Works

The app bypasses generic object estimation and relies purely on geometric trigonometry. The application isolates three crucial points on the visible side of the body: **Shoulder, Elbow, and Wrist**. 

It continuously calculates the interior angle of the elbow vector:
* **STATE "UP":** The user is in a plank position with arms straight (Elbow angle is **> 160°**).
* **STATE "DOWN":** The user drops chest-to-floor, bending arms (Elbow angle falls **< 90°**).

> 🔄 **Repetition Rule:** A push-up increments by **+1** *ONLY* when the user completes a full structural cycle: `UP` ➔ `DOWN` ➔ `UP`. Partial repetitions or half-bends fail to register, encouraging perfect workout form.

---

## 📁 Project Architecture

The codebase follows a clean, modular structure separating the device hardware stream, visual drawing metrics, and operational logic matrices:

```text
lib/
│
├── controllers/
│   └── pushup_counter_controller.dart  # Vector calculations and rep state-machine
│
├── services/
│   └── pose_detector_service.dart     # Camera frame formatting and ML Kit integration
│
├── ui/
│   ├── camera_view_screen.dart        # Fullscreen Stack layout displaying camera view
│   └── pose_painter.dart              # CustomPainter rendering the skeleton canvas dots/lines
│
└── main.dart                          # Core entry point initializing background services
