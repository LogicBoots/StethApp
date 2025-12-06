#!/usr/bin/env python3
"""
Create a minimal working TFLite model directly
"""

import tensorflow as tf
import numpy as np

def create_minimal_tflite():
    """
    Create a minimal TFLite model that works with older TFLite versions
    """
    
    # Create a simple concrete function that does basic operations
    @tf.function
    def simple_model(x):
        # Input shape: [1, 32000, 1]
        # Simple operations that should be compatible
        x = tf.reduce_mean(x, axis=1)  # Global average pooling: [1, 1]
        x = tf.reshape(x, [1, 1])      # Ensure shape
        
        # Simple dense layer simulation with fixed weights
        # This is just for testing - replace with your real model
        w1 = tf.constant([[0.1, 0.2, 0.3]], dtype=tf.float32)  # [1, 3]
        x = tf.matmul(x, w1)  # [1, 3]
        
        # Softmax
        x = tf.nn.softmax(x)
        return x
    
    # Create concrete function with fixed input signature
    concrete_func = simple_model.get_concrete_function(
        tf.TensorSpec(shape=[1, 32000, 1], dtype=tf.float32)
    )
    
    # Convert to TFLite with minimal settings
    converter = tf.lite.TFLiteConverter.from_concrete_functions([concrete_func])
    converter.optimizations = []  # No optimizations
    
    try:
        tflite_model = converter.convert()
        
        # Save the model
        with open("assets/models/minimal_model.tflite", "wb") as f:
            f.write(tflite_model)
        
        print("✅ Minimal TFLite model created!")
        
        # Test the model
        interpreter = tf.lite.Interpreter(model_content=tflite_model)
        interpreter.allocate_tensors()
        
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        print(f"Input shape: {input_details[0]['shape']}")
        print(f"Output shape: {output_details[0]['shape']}")
        
        # Test with dummy data
        test_input = np.random.randn(1, 32000, 1).astype(np.float32)
        interpreter.set_tensor(input_details[0]['index'], test_input)
        interpreter.invoke()
        output = interpreter.get_tensor(output_details[0]['index'])
        print(f"Test output: {output}")
        
        return True
        
    except Exception as e:
        print(f"❌ Failed to create minimal model: {e}")
        return False

if __name__ == "__main__":
    print(f"TensorFlow version: {tf.__version__}")
    
    success = create_minimal_tflite()
    if success:
        print("\n" + "="*50)
        print("SUCCESS! Created minimal_model.tflite")
        print("This is a basic model that should work with TFLite Flutter 0.11.0")
        print("Update your Dart code to use 'minimal_model.tflite'")
        print("="*50)
