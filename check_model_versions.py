#!/usr/bin/env python3
import tensorflow as tf

print("TensorFlow version:", tf.__version__)
print("TensorFlow Lite version compatibility:")
print("- TF 2.15+ uses FULLY_CONNECTED v12+ (incompatible with TFLite Flutter 0.11.0)")
print("- TF 2.8-2.14 uses FULLY_CONNECTED v11 (compatible)")
print("- TF 2.4-2.7 uses FULLY_CONNECTED v9-v10 (compatible)")

print("\n" + "="*60)

# Check your original model
try:
    print("\nAnalyzing best_model.tflite...")
    interpreter = tf.lite.Interpreter(model_path='assets/models/best_model.tflite')
    interpreter.allocate_tensors()
    
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    print(f"Input shape: {input_details[0]['shape']}")
    print(f"Output shape: {output_details[0]['shape']}")
    
    # Get operation details
    ops = interpreter._get_ops_details()
    print("Operations used:")
    for op in ops:
        op_name = op.get('op_name', 'Unknown')
        version = op.get('version', 'Unknown')
        print(f"  - {op_name} (version {version})")
        
        # Check if this is the problematic FULLY_CONNECTED v12
        if op_name == 'FULLY_CONNECTED' and version == 12:
            print("    ❌ INCOMPATIBLE: This version is not supported by TFLite Flutter 0.11.0")
        elif op_name == 'FULLY_CONNECTED':
            print(f"    ✅ COMPATIBLE: Version {version} should work")
            
except Exception as e:
    print(f"❌ Error analyzing best_model.tflite: {e}")

print("\n" + "="*60)

# Check minimal model
try:
    print("\nAnalyzing minimal_model.tflite...")
    interpreter2 = tf.lite.Interpreter(model_path='assets/models/minimal_model.tflite')
    interpreter2.allocate_tensors()
    
    input_details2 = interpreter2.get_input_details()
    output_details2 = interpreter2.get_output_details()
    
    print(f"Input shape: {input_details2[0]['shape']}")
    print(f"Output shape: {output_details2[0]['shape']}")
    
    ops2 = interpreter2._get_ops_details()
    print("Operations used:")
    for op in ops2:
        op_name = op.get('op_name', 'Unknown')
        version = op.get('version', 'Unknown')
        print(f"  - {op_name} (version {version})")
        
except Exception as e:
    print(f"❌ Error analyzing minimal_model.tflite: {e}")

print("\n" + "="*60)
print("SUMMARY:")
print("TFLite Flutter 0.11.0 supports:")
print("- FULLY_CONNECTED versions up to v11")
print("- Most other operations up to TF 2.14 level")
print("Your best_model.tflite likely uses FULLY_CONNECTED v12 (from TF 2.15+)")
print("The minimal_model.tflite should be compatible")
