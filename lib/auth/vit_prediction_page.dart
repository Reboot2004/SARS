import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:photo_view/photo_view.dart';

class VITPredictionPage extends StatefulWidget {
  @override
  _VITPredictionPageState createState() => _VITPredictionPageState();
}

class _VITPredictionPageState extends State<VITPredictionPage> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  String _result = '';
  String? _selectedSampleImage;
  final Map<String, String> sampleImages = {
    'Sample Image 1': 'assets/images/sample1.jpeg',
    'Sample Image 2': 'assets/images/sample2.jpeg',
  };
  final List<String> groundTruths = [
    'Maize',
    'Wheat',
  ];

  // Pick an image from the gallery
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _selectedSampleImage = null; // Reset sample image selection
      });
    }
  }

  // Load a sample image
  Future<void> _loadSampleImage(String assetPath) async {
    setState(() {
      _image = null; // Reset _image as it's for user-uploaded files
      _selectedSampleImage = sampleImages.keys.firstWhere(
            (key) => sampleImages[key] == assetPath,
      );
      _result = ''; // Clear prediction result for a new sample
    });
  }

  // Send the image to the Flask server for prediction
  Future<void> _predict() async {
    if (_image == null && _selectedSampleImage == null) return;

    try {
      http.MultipartRequest request = http.MultipartRequest(
        'POST',
        Uri.parse('http://172.16.20.27:5000/predict_vit'), // Replace with your Flask server URL
      );

      if (_image != null) {
        // User-uploaded file
        request.files.add(
          await http.MultipartFile.fromPath('image', _image!.path),
        );
      } else if (_selectedSampleImage != null) {
        // Asset image
        final assetPath = sampleImages[_selectedSampleImage]!;
        final byteData = await rootBundle.load(assetPath); // Load the asset
        final fileBytes = byteData.buffer.asUint8List();

        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            fileBytes,
            filename: _selectedSampleImage, // Give it a name
          ),
        );
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      // Decode JSON response
      final decodedResponse = json.decode(responseData);

      // Extract prediction field
      final prediction = decodedResponse['predicted_class']; // Update this key based on your JSON structure

      setState(() {
        _result = prediction != null ? prediction.toString() : 'No prediction found.';
      });
    } catch (e) {
      setState(() {
        _result = 'Error: Unable to fetch prediction.';
      });
    }
  }


  // Get ground truth for selected sample
  String? _getGroundTruth() {
    if (_selectedSampleImage != null) {
      int index = sampleImages.keys.toList().indexOf(_selectedSampleImage!);
      return groundTruths[index];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('VIT Prediction'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Select an Image',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 20),
                _childImageWidget(),
                SizedBox(height: 20),
                DropdownButton<String>(
                  value: _selectedSampleImage,
                  hint: Text(
                    'Select a Sample Image',
                    style: TextStyle(color: Colors.white),
                  ),
                  dropdownColor: Colors.black,
                  items: sampleImages.keys.map((String key) {
                    return DropdownMenuItem<String>(
                      value: key,
                      child: Text(
                        key,
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    _loadSampleImage(sampleImages[newValue]!);
                  },
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _pickImage,
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(Colors.blueAccent),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    padding: MaterialStateProperty.all(
                      EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    ),
                  ),
                  child: Text(
                    'Pick Image',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _predict,
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(Colors.greenAccent),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    padding: MaterialStateProperty.all(
                      EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    ),
                  ),
                  child: Text(
                    'Predict',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
                SizedBox(height: 30),
                Text(
                  'Prediction Result:',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.lightBlueAccent,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  _result.isNotEmpty ? _result : 'No result yet.',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.tealAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_getGroundTruth() != null)
                  Column(
                    children: [
                      SizedBox(height: 10),
                      Text(
                        'Ground Truth:',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _getGroundTruth()!,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.orange,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget to display the image
  Widget _childImageWidget() {
    if (_image != null) {
      // Render user-selected file
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (BuildContext imageContext) => PhotoViewPage(
                imageFile: _image!,
                isAsset: false,
              ),
            ),
          );
        },
        child: Image.file(
          _image!,
          height: 200,
          fit: BoxFit.cover,
        ),
      );
    } else if (_selectedSampleImage != null) {
      // Render sample image from assets
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (BuildContext imageContext) => PhotoViewPage(
                imageAssetPath: sampleImages[_selectedSampleImage]!,
                isAsset: true,
              ),
            ),
          );
        },
        child: Image.asset(
          sampleImages[_selectedSampleImage]!,
          height: 200,
          fit: BoxFit.cover,
        ),
      );
    } else {
      return Text(
        'No image selected.',
        style: TextStyle(color: Colors.white),
      );
    }
  }
}

// PhotoViewPage class for zooming into the image
class PhotoViewPage extends StatelessWidget {
  final File? imageFile;
  final String? imageAssetPath;
  final bool isAsset;

  const PhotoViewPage({
    this.imageFile,
    this.imageAssetPath,
    required this.isAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: PhotoView(
          imageProvider: isAsset
              ? AssetImage(imageAssetPath!)
              : FileImage(imageFile!) as ImageProvider,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
          heroAttributes: const PhotoViewHeroAttributes(tag: "imageHero"),
        ),
      ),
    );
  }
}
