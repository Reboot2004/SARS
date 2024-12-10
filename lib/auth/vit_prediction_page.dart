// vit_prediction_page.dart
import 'dart:convert'; // Import this for JSON decoding
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class VITPredictionPage extends StatefulWidget {
  @override
  _VITPredictionPageState createState() => _VITPredictionPageState();
}

class _VITPredictionPageState extends State<VITPredictionPage> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  String _result = '';
  final List<String> groundTruths = [
    'Ground Truth 1',
    'Ground Truth 2',
    'Ground Truth 3',
  ];

  // Pick an image from the gallery
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  // Send the image to the Flask server for prediction
  // Future<void> _predict() async {
  //   if (_image == null) return;
  //
  //   final request = http.MultipartRequest(
  //     'POST',
  //     Uri.parse('http://172.16.20.30:5000/predict_vit'), // Replace with your Flask server URL
  //   );
  //   request.files.add(
  //     await http.MultipartFile.fromPath('image', _image!.path),
  //   );
  //
  //   final response = await request.send();
  //   final responseData = await response.stream.bytesToString();
  //
  //   setState(() {
  //     _result = responseData;
  //   });
  // }


// Send the image to the Flask server for prediction
  Future<void> _predict() async {
    if (_image == null) return;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://172.16.20.30:5000/predict_vit'), // Replace with your Flask server URL
    );
    request.files.add(
      await http.MultipartFile.fromPath('image', _image!.path),
    );

    try {
      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      // Decode JSON response
      final decodedResponse = json.decode(responseData);

      // Extract prediction field
      final prediction = decodedResponse['predicted_class']; // Update 'prediction' key based on your JSON structure

      setState(() {
        _result = prediction != null ? prediction.toString() : 'No prediction found.';
      });
    } catch (e) {
      setState(() {
        _result = 'Error: Unable to fetch prediction.';
      });
    }
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
                _image == null
                    ? Text(
                  'No image selected.',
                  style: TextStyle(color: Colors.white),
                )
                    : GestureDetector(
                  onTap: () {
                    // Open a zoomable view of the image
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (BuildContext imageContext) =>
                            PhotoViewPage(image: _image!),
                      ),
                    );
                  },
                  child: Image.file(
                    _image!,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _pickImage,
                  style: ButtonStyle(
                    backgroundColor:
                    MaterialStateProperty.all(Colors.blueAccent),
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
                    backgroundColor:
                    MaterialStateProperty.all(Colors.greenAccent),
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
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  _result.isNotEmpty ? _result : 'No result yet.',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// PhotoViewPage class for zooming into the image
class PhotoViewPage extends StatelessWidget {
  final File image;

  const PhotoViewPage({required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: PhotoView(
          imageProvider: FileImage(image),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
          heroAttributes: const PhotoViewHeroAttributes(tag: "imageHero"),
        ),
      ),
    );
  }
}