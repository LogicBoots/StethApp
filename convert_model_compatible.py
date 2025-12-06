#!/usr/bin/env python3
"""
Convert existing TFLite model with compatibility flags for TFLite Flutter 0.11.0
"""

import tensorflow as tf
import numpy as np

def convert_with_compatibility_flags():
    """
    Load existing TFLite model and convert with compatibility flags
    """
    input_model_path = "assets/models/best_model.tflite"
    output_model_path = "assets/models/best_model_compatible.tflite"
    
    try:
        # Load the existing TFLite model
        interpreter = tf.lite.Interpreter(model_path=input_model_path)
        interpreter.allocate_tensors()
        
        # Get input and output details
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        print("Original model details:")
        print(f"Input shape: {input_details[0]['shape']}")
        print(f"Output shape: {output_details[0]['shape']}")
        
        # Since we can't directly convert from TFLite back to TF, 
        # we need to create a compatible version
        # This requires your original model source
        
        print("❌ Cannot directly convert TFLite to compatible TFLite")
        print("You need to recreate the model with TensorFlow 2.8 or 2.9")
        
        return False
        
    except Exception as e:
        print(f"Error: {e}")
        return False

def create_compatible_converter_script():
    """
    Create a template script for converting from original model
    """
    script_content = '''
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
'''
    
    with open("create_compatible_model.py", "w") as f:
        f.write(script_content)
    
    print("✅ Created 'create_compatible_model.py' template")
    print("Edit it with your original model path and run it")

if __name__ == "__main__":
    # Try to convert existing model
    success = convert_with_compatibility_flags()
    
    if not success:
        # Create template script for manual conversion
        create_compatible_converter_script()
        
        print("\n" + "="*50)
        print("SOLUTION:")
        print("1. Edit 'create_compatible_model.py' with your original model path")
        print("2. Run: python create_compatible_model.py")
        print("3. Replace best_model.tflite with best_model_compatible.tflite")
        print("="*50)
