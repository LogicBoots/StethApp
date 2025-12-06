#!/usr/bin/env python3
"""
test_tflite_audio_folder.py

Runs inference on a folder of .wav files using your exported TFLite model.
"""

import numpy as np
import tensorflow as tf
import soundfile as sf
import librosa  # pip install librosa
from pathlib import Path

# ================= CONFIG =================
TFLITE_MODEL_PATH = Path("./models/end_to_end_model_legacy.tflite")
AUDIO_FOLDER = Path("./data/newtest")   # folder with .wav files
TARGET_LENGTH = 32000   # 2 sec at 16kHz
TARGET_SR = 16000       # sample rate expected by model
CLASS_NAMES = ["Normal", "Pneumonia", "TB"]
# ==========================================

def load_audio(path, target_len=32000, target_sr=16000):
    # Read audio (any SR) and resample to target SR
    audio, sr = sf.read(path)
    if audio.ndim > 1:
        audio = np.mean(audio, axis=1)  # mono
    if sr != target_sr:
        audio = librosa.resample(audio, orig_sr=sr, target_sr=target_sr)

    # Pad or truncate to fixed length
    if len(audio) < target_len:
        audio = np.pad(audio, (0, target_len - len(audio)))
    else:
        audio = audio[:target_len]

    audio = audio.astype(np.float32)
    return np.expand_dims(audio, axis=(0, -1))  # [1, 32000, 1]

def run_tflite(interpreter, audio_tensor):
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    interpreter.set_tensor(input_details[0]['index'], audio_tensor)
    interpreter.invoke()
    return interpreter.get_tensor(output_details[0]['index'])

if __name__ == "__main__":
    interpreter = tf.lite.Interpreter(model_path=str(TFLITE_MODEL_PATH))
    interpreter.allocate_tensors()

    wav_files = list(AUDIO_FOLDER.glob("*.wav"))
    if not wav_files:
        print("❌ No .wav files found in", AUDIO_FOLDER)
    else:
        for wav_file in wav_files:
            audio_tensor = load_audio(wav_file, TARGET_LENGTH, TARGET_SR)
            preds = run_tflite(interpreter, audio_tensor)

            pred_class = np.argmax(preds)
            class_name = CLASS_NAMES[pred_class]
            probs = ", ".join([f"{c}: {p:.4f}" for c, p in zip(CLASS_NAMES, preds[0])])

            print(f"🎵 {wav_file.name} → {class_name} ({probs})")
