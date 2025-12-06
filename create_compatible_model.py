
import tensorflow as tf

# Load your original model (before TFLite conversion)
# Replace this with your actual model loading code
model = tf.keras.models.load_model("your_original_model.h5")

# Create converter with compatibility settings
converter = tf.lite.TFLiteConverter.from_keras_model(model)

# Set compatibility options for TFLite Flutter 0.11.0
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_ops = [
    tf.lite.OpsSet.TFLITE_BUILTINS,
]

# Force use of older op versions
converter.experimental_new_converter = False
converter.experimental_new_quantizer = False

# Convert with compatibility
try:
    tflite_model = converter.convert()
    
    # Save compatible model
    with open("assets/models/best_model_compatible.tflite", "wb") as f:
        f.write(tflite_model)
    
    print("✅ Compatible model created!")
    
except Exception as e:
    print(f"Conversion failed: {e}")
