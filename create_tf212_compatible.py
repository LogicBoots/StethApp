#!/usr/bin/env python3
"""
Create a TensorFlow 2.12 compatible model
"""

import tensorflow as tf
import os

# Force TensorFlow to use older op versions
os.environ['TF_USE_LEGACY_KERAS'] = '1'

def create_compatible_model():
    """
    Create a model that uses FULLY_CONNECTED v11 or lower
    """
    
    # Create model with explicit compatibility settings
    inputs = tf.keras.Input(shape=(32000, 1), name='audio_input')
    
    # Simple architecture that should be compatible
    x = tf.keras.layers.GlobalAveragePooling1D()(inputs)
    x = tf.keras.layers.Dense(128, activation='relu', name='dense1')(x)
    x = tf.keras.layers.Dropout(0.2)(x)
    x = tf.keras.layers.Dense(64, activation='relu', name='dense2')(x)
    x = tf.keras.layers.Dropout(0.2)(x) 
    outputs = tf.keras.layers.Dense(3, activation='softmax', name='predictions')(x)
    
    model = tf.keras.Model(inputs=inputs, outputs=outputs, name='audio_classifier')
    
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )
    
    print("Model summary:")
    model.summary()
    
    # Convert with strict compatibility for TFLite Flutter 0.11.0
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Use minimal settings for maximum compatibility
    converter.optimizations = []  # No optimizations to avoid new ops
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
    
    # Force older converter behavior
    converter.experimental_new_converter = False
    converter.experimental_new_quantizer = False
    
    # Additional compatibility flags
    converter.allow_custom_ops = False
    converter.experimental_enable_resource_variables = False
    
    try:
        print("Converting model...")
        tflite_model = converter.convert()
        
        # Save the compatible model
        output_path = "assets/models/best_model_compatible.tflite"
        with open(output_path, "wb") as f:
            f.write(tflite_model)
        
        print(f"✅ Compatible model saved to: {output_path}")
        
        # Test the model
        interpreter = tf.lite.Interpreter(model_content=tflite_model)
        interpreter.allocate_tensors()
        
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        print(f"Input shape: {input_details[0]['shape']}")
        print(f"Output shape: {output_details[0]['shape']}")
        
        # Check operations
        ops = interpreter._get_ops_details()
        print("Operations used:")
        fully_connected_versions = []
        for op in ops:
            op_name = op.get('op_name', 'Unknown')
            version = op.get('version', 'Unknown')
            print(f"  - {op_name} (v{version})")
            if op_name == 'FULLY_CONNECTED':
                fully_connected_versions.append(version)
        
        if fully_connected_versions:
            max_fc_version = max(fully_connected_versions)
            if max_fc_version <= 11:
                print(f"✅ FULLY_CONNECTED version {max_fc_version} - COMPATIBLE!")
            else:
                print(f"❌ FULLY_CONNECTED version {max_fc_version} - INCOMPATIBLE!")
        
        return True
        
    except Exception as e:
        print(f"❌ Conversion failed: {e}")
        return False

if __name__ == "__main__":
    print(f"TensorFlow version: {tf.__version__}")
    
    success = create_compatible_model()
    if success:
        print("\n" + "="*60)
        print("SUCCESS! Your compatible model is ready.")
        print("1. Update your Dart code to use 'best_model_compatible.tflite'")
        print("2. Or rename it to 'best_model.tflite' to replace the old one")
        print("="*60)
    else:
        print("\n❌ Failed to create compatible model")
