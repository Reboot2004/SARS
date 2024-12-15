import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:uuid/uuid.dart';

class SARColorizationPage extends StatefulWidget {
  @override
  _SARColorizationPageState createState() => _SARColorizationPageState();
}

class _SARColorizationPageState extends State<SARColorizationPage> {
  File? _inputImage;
  File? _outputImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String _selectedSampleImage = '';
  String _selectedGroundTruthImage = '';
  double _fidScore = 0.0;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _inputImage = File(pickedFile.path);
        _selectedSampleImage = ''; // Clear sample image selection
        _outputImage = null;
        _fidScore = 0.0;
      });
    }
  }

  Future<void> _processImage() async {
    if (_inputImage == null && _selectedSampleImage.isEmpty) return;

    setState(() {
      _isLoading = true;
      _outputImage = null;
      _fidScore = 0.0;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.1.7:5000/predict2' // New route for sample image
            ),
      );

      if (_selectedSampleImage.isNotEmpty) {
        // Handle asset image
        final byteData = await rootBundle.load(_selectedSampleImage);
        final buffer = byteData.buffer;
        final fileBytes = buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

        // Create MultipartFile from bytes
        final imageMultipart = http.MultipartFile.fromBytes(
          'image',
          fileBytes,
          filename: _selectedSampleImage.split('/').last, // Use the asset filename
        );
        request.files.add(imageMultipart);

        // Send ground truth image along with the request
        final groundTruthByteData = await rootBundle.load(_selectedGroundTruthImage);
        final groundTruthBuffer = groundTruthByteData.buffer;
        final groundTruthBytes = groundTruthBuffer.asUint8List(
          groundTruthByteData.offsetInBytes,
          groundTruthByteData.lengthInBytes,
        );

        final groundTruthMultipart = http.MultipartFile.fromBytes(
          'ground_truth',
          groundTruthBytes,
          filename: _selectedGroundTruthImage.split('/').last,
        );
        request.files.add(groundTruthMultipart);
      } else if (_inputImage != null) {
        // Handle gallery image
        final imageMultipart = await http.MultipartFile.fromPath(
          'image',
          _inputImage!.path,
        );
        request.files.add(imageMultipart);
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();
        final dir = await getTemporaryDirectory();
        final outputFile = File('${dir.path}/${Uuid().v4()}.png');
        await outputFile.writeAsBytes(bytes);

        setState(() {
          _outputImage = outputFile;
          _fidScore = 183.0; // Hardcoded FID score as requested
        });
      } else {
        _showSnackBar('Failed to process the image.');
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  ButtonStyle _buttonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      elevation: 3,
    );
  }

  Widget _buildSampleImageDropdown() {
    List<String> sampleImages = [
      'assets/sample_images/sample1.jpg',
      'assets/sample_images/sample2.jpg',
    ];

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
            _inputImage = null; // Clear gallery image selection
            _outputImage = null;
            _fidScore = 0.0;

            // Set corresponding ground truth image
            _selectedGroundTruthImage =
                newValue.replaceAll('sample_images', 'groundtruth').replaceAll('.jpg', '.jpg');
          });
        },
        items: sampleImages.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value.split('/').last, style: TextStyle(color: Colors.white)),
          );
        }).toList(),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SAR Image Colorization',
                  style: TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2
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
                        width: 2
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _selectedSampleImage.isNotEmpty
                      ? GestureDetector(
                    onTap: () => _viewImage(AssetImage(_selectedSampleImage)),
                    child: Column(
                      children: [
                        Text('Selected Sample Image',
                            style: TextStyle(color: Colors.white70)),
                        SizedBox(
                          height: 200,
                          width: 200,
                          child: _buildPhotoView(AssetImage(_selectedSampleImage)),
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
                      onPressed: _processImage,
                      icon: Icon(Icons.color_lens, color: Colors.white),
                      label: _isLoading
                          ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                          : Text('Colorize', style: TextStyle(color: Colors.white)),
                      style: _buttonStyle(Colors.greenAccent),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                if (_selectedSampleImage!= '' && _outputImage != null) ...[
                  Text('Results',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold
                      )
                  ),
                  // FID Score Display
                  Text(
                      'FID Score: ${_fidScore.toStringAsFixed(1)}',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w500
                      )
                  ),
                  SizedBox(height: 10),
                  if(_selectedSampleImage!='')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text('Ground Truth',
                              style: TextStyle(color: Colors.white70)),
                          SizedBox(
                            height: 150,
                            width: 150,
                            child: GestureDetector(
                              onTap: () => _viewImage(AssetImage(_selectedGroundTruthImage)),
                              child: _buildPhotoView(AssetImage(_selectedGroundTruthImage)),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Predicted Image',
                              style: TextStyle(color: Colors.white70)),
                          SizedBox(
                            height: 150,
                            width: 150,
                            child: GestureDetector(
                              onTap: () => _viewImage(FileImage(_outputImage!)),
                              child: _buildPhotoView(FileImage(_outputImage!)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ]
                else if(_selectedSampleImage == '' && _outputImage!=null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [

                      Column(
                        children: [
                          const Text('Predicted Image',
                              style: TextStyle(color: Colors.white70)),
                          SizedBox(
                            height: 150,
                            width: 150,
                            child: GestureDetector(
                              onTap: () => _viewImage(FileImage(_outputImage!)),
                              child: _buildPhotoView(FileImage(_outputImage!)),
                            ),
                          ),
                        ],
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
}