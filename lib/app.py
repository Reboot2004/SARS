import os
import onnxruntime
import numpy as np
from flask import Flask, request, jsonify, send_file, Response
from flask_cors import CORS
from keras.models import load_model
from keras.preprocessing import image
from PIL import Image
from io import BytesIO
import gc  # Import garbage collector for memory management
import torch
from torchvision import transforms  # For image preprocessing in ViT
from patchify import patchify
import cv2
#from torchmetrics.image.fid import FrechetInceptionDistance  # Import FID calculation
app = Flask(__name__)
CORS(app)  # Allow cross-origin requests

# Load the VGG16 model from .h5 file
model = load_model('crop_prediction_VGG16#3.h5')
keras_model = load_model('model.keras', custom_objects={"dice_loss": lambda x, y: x, "dice_coef": lambda x, y: x})
# Load the ONNX model for SAR image colorization
onnx_model_path = "sar2rgb.onnx"
onnx_sess = onnxruntime.InferenceSession(onnx_model_path)
#fid = FrechetInceptionDistance().to(torch.device("cuda" if torch.cuda.is_available() else "cpu"))
#Load a pre-trained VIT Model

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
vit_model_path = "vit_model.pth"  # Replace with the actual path to your .pth file
vit_model = torch.load(vit_model_path, map_location=device)
vit_model.eval()  # Set the model to evaluation mode

cf = {
    "image_size": 256,
    "num_channels": 3,
    "patch_size": 16,
    "flat_patches_shape": (256, 48)  # Updated dynamically later
}
# List of class names for VGG16 model and VIT Model
class_names = ['jute', 'maize', 'rice', 'sugarcane', 'wheat']

# CLASSIFICATION USING VGG16
@app.route('/predict', methods=['POST'])
def predict_vgg16():
    if 'image' not in request.files:
        return jsonify({'error': 'No image provided'}), 400

    img_file = request.files['image']

    # Clear any previous image and data before loading new one
    gc.collect()

    # Read the image file into memory (no need to save to disk)
    img = Image.open(BytesIO(img_file.read()))

    # Preprocess the image for VGG16 model
    img = img.resize((224, 224))  # Resize image to the expected size
    img_array = image.img_to_array(img)
    img_array = np.expand_dims(img_array, axis=0)

    # Make prediction
    preds = model.predict(img_array)

    # Find the index of the class with the highest probability
    predicted_class_index = np.argmax(preds)
    predicted_class = class_names[predicted_class_index]

    # Return the predicted class
    return jsonify(predicted_class)

# SAR Colorization
import torch
import numpy as np
from scipy.linalg import sqrtm
from PIL import Image
from torchvision.transforms import functional as F
import torchvision.transforms.v2 as v2
import gc
from io import BytesIO
from torchvision import models
# Function to extract features from Inception v3
def extract_features(images, model):
    print("extarct")
    images = images.cuda() if torch.cuda.is_available() else images
    with torch.no_grad():
        features = model(images)
    return features.cpu().numpy()

# Function to calculate FID
# def calculate_fid(real_features, generated_features):
#     real_img_preprocessed = preprocess_image(real_img)
#     generated_img_preprocessed = preprocess_image(generated_img)
#
#         # Extract features using InceptionV3
#     real_features = model.predict(real_img_preprocessed)
#     generated_features = model.predict(generated_img_preprocessed)
#
#         # Compute mean and covariance for the real and generated features
#     mu_real = np.mean(real_features, axis=0)
#     mu_gen = np.mean(generated_features, axis=0)
#
#     #sigma_real = np.cov(real_features, rowvar=False)
#     #sigma_gen = np.cov(generated_features, rowvar=False)
#
#         # Compute the FID score
#     diff = mu_real - mu_gen
#     #covmean = sqrtm(sigma_real.dot(sigma_gen))
#
#         # If covmean is complex, take the real part
#     #if np.iscomplexobj(covmean):
#     #    covmean = covmean.real
#
#     fid = diff.dot(diff) #+ np.trace(sigma_real + sigma_gen - 2 * covmean)
#
#     return fid

@app.route('/predict_sample', methods=['POST'])
def predict_sample():
    if 'sample_image' not in request.files or 'ground_truth' not in request.files:
        return jsonify({'error': 'Both sample and ground truth images are required'}), 400

    sample_file = request.files['sample_image']
    groundtruth_file = request.files['ground_truth']

    # Clear previous data
    gc.collect()

    try:
        # Load Inception model (e.g., torchvision.models.inception_v3)
        inception = models.inception_v3(weights='DEFAULT', transform_input=False).eval()
        print("1")
        transform = v2.Compose([
            v2.Resize(299, antialias=True),
            v2.CenterCrop(299),
            v2.ToImage(),
            v2.ToDtype(torch.float32, scale=True),
            v2.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        ])
        print("1")
        # Process the sample image
        sample_img = Image.open(BytesIO(sample_file.read())).convert('RGB')
        sample_tensor = transform(sample_img).unsqueeze(0)  # Add batch dimension
        print("1")
        # Generate the image using ONNX model
        expected_size = (256, 256)  # Replace with ONNX model input size
        sample_img = sample_img.resize(expected_size, Image.Resampling.LANCZOS)
        sample_array = np.array(sample_img).transpose(2, 0, 1)
        sample_array = sample_array.astype(np.float32) / 255.0
        sample_array = (sample_array - 0.5) / 0.5
        sample_array = np.expand_dims(sample_array, axis=0)
        inputs = {onnx_sess.get_inputs()[0].name: sample_array}
        output = onnx_sess.run(None, inputs)
        print("1")
        # Post-process generated image
        generated_img_array = output[0].squeeze().transpose(1, 2, 0)
        generated_img_array = (generated_img_array + 1) / 2
        generated_img_array = (generated_img_array * 255).astype(np.uint8)
        generated_img = Image.fromarray(generated_img_array)
        print("1")
        # Prepare tensors for feature extraction
        generated_tensor = transform(generated_img).unsqueeze(0)
        groundtruth_img = Image.open(BytesIO(groundtruth_file.read())).convert('RGB')
        groundtruth_tensor = transform(groundtruth_img).unsqueeze(0)
        print("1")
        # Extract features
        generated_features = extract_features(generated_tensor, inception)
        groundtruth_features = extract_features(groundtruth_tensor, inception)
        print("1")
        # Compute FID
        fid_score = calculate_fid(groundtruth_features, generated_features)
        print("1")
        # Prepare the generated image for response
        img_byte_arr = BytesIO()
        generated_img.save(img_byte_arr, format='PNG')
        img_byte_arr.seek(0)
        print("1")
        return jsonify({
            'fid_score': fid_score,
            'generated_image': img_byte_arr.getvalue().hex()
        })

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/predict2', methods=['POST'])
def predict_onnx():
    if 'image' not in request.files:
        return jsonify({'error': 'No image provided'}), 400

    img_file = request.files['image']

    # Clear any previous image and data before loading new one
    gc.collect()

    # Read and preprocess the image for the ONNX model
    img = Image.open(BytesIO(img_file.read()))
    img = img.resize((256, 256))  # Adjust size as needed
    print(np.array(img))
    img = np.array(img).transpose(2, 0, 1)  # HWC to CHW
    img = img.astype(np.float32) / 255.0  # Normalize to [0, 1]
    img = (img - 0.5) / 0.5  # Normalize to [-1, 1]
    img = np.expand_dims(img, axis=0)  # Add batch dimension

    # Run the ONNX model
    inputs = {onnx_sess.get_inputs()[0].name: img}
    output = onnx_sess.run(None, inputs)

    # Post-process the output image
    output_image = output[0].squeeze().transpose(1, 2, 0)  # CHW to HWC
    output_image = (output_image + 1) / 2  # Normalize to [0, 1]
    output_image = (output_image * 255).astype(np.uint8)  # Denormalize to [0, 255]

    # Convert to Image and return as response
    output_image = Image.fromarray(output_image)
    img_byte_arr = BytesIO()
    output_image.save(img_byte_arr, format='PNG')
    img_byte_arr.seek(0)

    return send_file(img_byte_arr, mimetype='image/png')


@app.route('/predict_vit', methods=['POST'])
def predict_vit():
    if 'image' not in request.files:
        return jsonify({'error': 'No image provided'}), 400

    img_file = request.files['image']
    gc.collect()  # Clear previous memory usage

    try:
        # Preprocessing for ViT
        preprocess = transforms.Compose([
            transforms.Resize((224, 224)),  # Resize image to 224x224
            transforms.ToTensor(),         # Convert image to tensor
            transforms.Normalize(mean=[0.5, 0.5, 0.5], std=[0.5, 0.5, 0.5])  # Normalize to [-1, 1]
        ])

        # Open and preprocess the image
        img = Image.open(BytesIO(img_file.read())).convert('RGB')  # Ensure RGB format
        img_tensor = preprocess(img).unsqueeze(0).to(device)  # Add batch dimension and move to device

        # Run the ViT model prediction
        with torch.no_grad():
            outputs = vit_model(img_tensor)
            predicted_class_index = torch.argmax(outputs, dim=1).item()  # Get index of the highest score
            predicted_class = class_names[predicted_class_index]  # Map to the class name
            print(outputs)
        return jsonify({'predicted_class': predicted_class})

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/flood', methods=['POST'])
def flood_prediction():
    if 'image' not in request.files:
        return jsonify({'error': 'No image provided'}), 400

    img_file = request.files['image']

    # Read the image file into memory
    img = Image.open(BytesIO(img_file.read()))
    img = img.convert("RGB")  # Ensure the image is in RGB mode

    # Preprocess the image for prediction
    img = img.resize((cf["image_size"], cf["image_size"]))
    img_array = np.array(img) / 255.0

    # Patchify the image for model input
    patch_shape = (cf["patch_size"], cf["patch_size"], cf["num_channels"])
    patches = patchify(img_array, patch_shape, cf["patch_size"])
    patches = np.reshape(patches, (-1, patch_shape[0] * patch_shape[1] * cf["num_channels"]))
    patches = patches.astype(np.float32)
    patches = np.expand_dims(patches, axis=0)

    # Predict the mask
    pred = keras_model.predict(patches, verbose=0)[0]
    pred = np.reshape(pred, (cf["image_size"], cf["image_size"], 1))
    pred = (pred > 0.5).astype(np.uint8)  # Threshold prediction

    # Find edges of the flood region using Canny edge detection
    pred_edges = cv2.Canny(pred[:, :, 0] * 255, 100, 200)

    # Make edges thicker using dilation
    kernel = np.ones((3, 3), np.uint8)  # Define a kernel (3x3 for moderate thickness)
    thicker_edges = cv2.dilate(pred_edges, kernel, iterations=1)

    # Create a blank RGB image to draw the thicker edges
    outline_mask = np.zeros((cf["image_size"], cf["image_size"], 3), dtype=np.uint8)
    outline_mask[:, :, 2] = thicker_edges  # Set the thicker edges to blue

    # Overlay the outline onto the original image
    img_array = (img_array * 255).astype(np.uint8)  # Convert to uint8
    combined_image = cv2.addWeighted(img_array, 0.9, outline_mask, 0.3, 0)
    # pred = model.predict(patches, verbose=0)[0]
    # pred = np.reshape(pred, (cf["image_size"], cf["image_size"], 1))
    # pred = (pred > 0.5).astype(np.uint8)  # Threshold prediction

    # # Create a blue mask for flood regions
    # blue_mask = np.zeros((cf["image_size"], cf["image_size"], 3), dtype=np.uint8)
    # blue_mask[:, :, 2] = pred[:, :, 0] * 255  # Set blue channel to 255 for flood regions

    # # Overlay the blue mask onto the original image
    # img_array = (img_array * 255).astype(np.uint8)  # Convert to uint8
    # combined_image = img_array.copy()

    # # Apply the blue mask only to flood regions
    # mask_indices = pred[:, :, 0] == 1
    # combined_image[mask_indices] = (0.7 * img_array[mask_indices] + 0.3 * blue_mask[mask_indices]).astype(np.uint8)

    # Save the combined image to a BytesIO object
    output = BytesIO()
    combined_pil_image = Image.fromarray(combined_image)
    combined_pil_image.save(output, format="PNG")
    output.seek(0)
    # Save the image in memory and send it as a response
    #     output = BytesIO()
    #     pred_pil_image = Image.fromarray(pred_image)
    #     pred_pil_image.save(output, format="PNG")
    #     output.seek(0)

    # Return the image as a response to the Flutter app
    return Response(output.getvalue(), mimetype='image/png')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
