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
  File? _inputImage;
  final ImagePicker _picker = ImagePicker();
  String _result = '';
  bool _isLoading = false;
  String _selectedSampleImage = '';
  final Map<String, String> sampleImages = {
    'Sample Image 1': 'assets/images/sample1.jpeg',
    'Sample Image 2': 'assets/images/sample2.jpeg',
  };
  final List<String> groundTruths = [
    'Maize',
    'Wheat',
  ];

  ButtonStyle _buttonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      elevation: 3,
    );
  }

  Widget _buildPhotoView(ImageProvider imageProvider) {
    return PhotoView(
      imageProvider: imageProvider,
      minScale: PhotoViewComputedScale.contained * 0.8,
      maxScale: PhotoViewComputedScale.covered * 2,
      backgroundDecoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
      ),
    );
  }

  void _viewImage(ImageProvider imageProvider) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => Scaffold(
          backgroundColor: Colors.black.withOpacity(0.8),
          body: Center(
            child: _buildPhotoView(imageProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildSampleImageDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButton<String>(
        value: _selectedSampleImage.isEmpty ? null : _selectedSampleImage,
        hint: Text('Select Sample Image', style: TextStyle(color: Colors.white70)),
        isExpanded: true,
        underline: SizedBox(),
        style: TextStyle(color: Colors.white),
        dropdownColor: Colors.grey[800],
        onChanged: (String? newValue) {
          setState(() {
            _selectedSampleImage = newValue!;
            _inputImage = null;
            _result = '';
          });
        },
        items: sampleImages.keys.map<DropdownMenuItem<String>>((String key) {
          return DropdownMenuItem<String>(
            value: key,
            child: Text(key, style: TextStyle(color: Colors.white)),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _inputImage = File(pickedFile.path);
        _selectedSampleImage = '';
        _result = '';
      });
    }
  }

  Future<void> _predict() async {
    if (_inputImage == null && _selectedSampleImage.isEmpty) return;

    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://172.17.20.02:5000/predict_vit'),
      );

      if (_selectedSampleImage.isNotEmpty) {
        // Handle asset image
        final assetPath = sampleImages[_selectedSampleImage]!;
        final byteData = await rootBundle.load(assetPath);
        final fileBytes = byteData.buffer.asUint8List();

        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            fileBytes,
            filename: _selectedSampleImage,
          ),
        );
      } else if (_inputImage != null) {
        // Handle gallery image
        request.files.add(
          await http.MultipartFile.fromPath('image', _inputImage!.path),
        );
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final decodedResponse = json.decode(responseData);

      setState(() {
        _result = decodedResponse['predicted_class'] ?? 'No prediction found.';
      });
    } catch (e) {
      setState(() {
        _result = 'Error: Unable to fetch prediction.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'VIT Crop Classification',
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 20),
                _buildSampleImageDropdown(),
                SizedBox(height: 20),
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedSampleImage.isNotEmpty || _inputImage != null
                          ? Colors.blueAccent
                          : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _selectedSampleImage.isNotEmpty
                      ? GestureDetector(
                    onTap: () => _viewImage(AssetImage(sampleImages[_selectedSampleImage]!)),
                    child: Column(
                      children: [
                        Text('Selected Sample Image',
                            style: TextStyle(color: Colors.white70)),
                        SizedBox(
                          height: 200,
                          width: 200,
                          child: _buildPhotoView(
                              AssetImage(sampleImages[_selectedSampleImage]!)),
                        ),
                      ],
                    ),
                  )
                      : _inputImage != null
                      ? GestureDetector(
                    onTap: () => _viewImage(FileImage(_inputImage!)),
                    child: SizedBox(
                      height: 200,
                      width: 200,
                      child: _buildPhotoView(FileImage(_inputImage!)),
                    ),
                  )
                      : SizedBox.shrink(),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.photo_library, color: Colors.white),
                      label: Text('Pick Image', style: TextStyle(color: Colors.white)),
                      style: _buttonStyle(Colors.blueAccent),
                    ),
                    SizedBox(width: 20),
                    ElevatedButton.icon(
                      onPressed: _predict,
                      icon: Icon(Icons.analytics, color: Colors.white),
                      label: _isLoading
                          ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                          : Text('Predict', style: TextStyle(color: Colors.white)),
                      style: _buttonStyle(Colors.greenAccent),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                if ((_selectedSampleImage.isNotEmpty || _inputImage != null) && _result.isNotEmpty) ...[
                  Text(
                    'Results',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text('Prediction', style: TextStyle(color: Colors.white70)),
                          Text(
                            _result,
                            style: TextStyle(
                              color: Colors.tealAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (_selectedSampleImage.isNotEmpty)
                        Column(
                          children: [
                            Text('Ground Truth', style: TextStyle(color: Colors.white70)),
                            Text(
                              groundTruths[sampleImages.keys.toList().indexOf(_selectedSampleImage)],
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}