#!/usr/bin/env python3
"""
Quick fix: Create a simple compatible model for testing
"""

import tensorflow as tf
import numpy as np

def create_simple_compatible_model():
    """
    Create a simple model compatible with TFLite Flutter 0.11.0
    """
    # Create a simple functional model
    inputs = tf.keras.Input(shape=(32000, 1), name='audio_input')
    x = tf.keras.layers.GlobalAveragePooling1D()(inputs)
    x = tf.keras.layers.Dense(64, activation='relu')(x)
    x = tf.keras.layers.Dense(32, activation='relu')(x)
    outputs = tf.keras.layers.Dense(3, activation='softmax', name='predictions')(x)
    
    model = tf.keras.Model(inputs=inputs, outputs=outputs)
    
    model.compile(
        optimizer='adam',
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )
    
    print("Model summary:")
    model.summary()
    
    # Convert to TFLite with strict compatibility
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Use minimal optimizations for maximum compatibility
    converter.optimizations = []  # No optimizations
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
    
    # Disable experimental features
    converter.experimental_new_converter = False
    converter.experimental_new_quantizer = False
    
    try:
        tflite_model = converter.convert()
        
        # Save the model
        with open("assets/models/simple_compatible_model.tflite", "wb") as f:
            f.write(tflite_model)
        
        print("✅ Simple compatible model created!")
        print("File: assets/models/simple_compatible_model.tflite")
        
        # Test the model
        interpreter = tf.lite.Interpreter(model_content=tflite_model)
        interpreter.allocate_tensors()
        
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        print(f"Input shape: {input_details[0]['shape']}")
        print(f"Output shape: {output_details[0]['shape']}")
        
        return True
        
    except Exception as e:
        print(f"❌ Failed to create model: {e}")
        return False

if __name__ == "__main__":
    print(f"TensorFlow version: {tf.__version__}")
    
    success = create_simple_compatible_model()
    if success:
        print("\n" + "="*50)
        print("NEXT STEPS:")
        print("1. Update Dart code to use 'simple_compatible_model.tflite'")
        print("2. Test the app")
        print("3. This model gives random predictions - replace with your trained model")
        print("="*50)
