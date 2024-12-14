import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:photo_view/photo_view.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';

class FloodPage extends StatefulWidget {
  @override
  _FloodPageState createState() => _FloodPageState();
}

class _FloodPageState extends State<FloodPage> {
  File? _inputImage;
  Uint8List? _outputImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String _selectedSampleImage = '';
  String _selectedGroundTruthImage = '';
  double _accuracyScore = 0.0;
  String _errorMessage = '';

  final List<String> _sampleImages = [
    'assets/images/sample1.png',
    'assets/images/sample2.png',
    'assets/images/sample3.png',
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
            _outputImage = null;
            _accuracyScore = 0.0;

            // Set corresponding ground truth image
            _selectedGroundTruthImage =
                newValue.replaceAll('images', 'masks').replaceAll('.png', '.png');
            _errorMessage = '';
          });
        },
        items: _sampleImages.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value.split('/').last, style: TextStyle(color: Colors.white)),
          );
        }).toList(),
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

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _inputImage = File(pickedFile.path);
        _selectedSampleImage = '';
        _outputImage = null;
        _accuracyScore = 0.0;
        _errorMessage = '';
      });
    }
  }

  Future<void> _predict() async {
    if (_inputImage == null && _selectedSampleImage.isEmpty) {
      setState(() {
        _errorMessage = 'Please select an image before predicting.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _outputImage = null;
      _errorMessage = '';
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://172.16.20.27:5000/flood'),
      );

      if (_selectedSampleImage.isNotEmpty) {
        // Handle asset image
        final byteData = await rootBundle.load(_selectedSampleImage);
        final buffer = byteData.buffer;
        final fileBytes = buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            fileBytes,
            filename: _selectedSampleImage.split('/').last,
          ),
        );

        // Add ground truth mask
        final maskByteData = await rootBundle.load(_selectedGroundTruthImage);
        final maskBuffer = maskByteData.buffer;
        final maskBytes = maskBuffer.asUint8List(
          maskByteData.offsetInBytes,
          maskByteData.lengthInBytes,
        );

        request.files.add(
          http.MultipartFile.fromBytes(
            'ground_truth',
            maskBytes,
            filename: _selectedGroundTruthImage.split('/').last,
          ),
        );
      } else if (_inputImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', _inputImage!.path),
        );
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();
        final dir = await getTemporaryDirectory();
        final outputFile = File('${dir.path}/${Uuid().v4()}.png');
        await outputFile.writeAsBytes(bytes);

        setState(() {
          _outputImage = bytes;
          _accuracyScore = 92.0; // Hardcoded accuracy as in original code
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to get prediction. Server returned ${response.statusCode}.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error occurred: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _refresh() {
    setState(() {
      _inputImage = null;
      _selectedSampleImage = '';
      _selectedGroundTruthImage = '';
      _outputImage = null;
      _accuracyScore = 0.0;
      _errorMessage = '';
    });
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
                  'Flood Detection',
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
                      onPressed: _predict,
                      icon: Icon(Icons.cloud_upload, color: Colors.white),
                      label: _isLoading
                          ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                          : Text('Predict', style: TextStyle(color: Colors.white)),
                      style: _buttonStyle(Colors.greenAccent),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                if (_outputImage != null) ...[
                  Text('Results',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold
                      )
                  ),
                  // Accuracy Score Display
                  Text(
                      'Model: UNETR   Accuracy: ${_accuracyScore.toStringAsFixed(1)}%',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w500
                      )
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          if (_outputImage != null && _selectedSampleImage!=null)
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
                              onTap: () => _viewImage(MemoryImage(_outputImage!)),
                              child: _buildPhotoView(MemoryImage(_outputImage!)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                if (_outputImage != null)
                  IconButton(
                    onPressed: _refresh,
                    icon: Icon(Icons.autorenew, color: Colors.white),
                    style: _buttonStyle(Colors.greenAccent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Keep the PhotoViewPage and ImageViewPage as they were in the original code
// PhotoViewPage for viewing selected image
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

// ImageViewPage for viewing prediction result
class ImageViewPage extends StatelessWidget {
  final Uint8List imageBytes;

  const ImageViewPage({required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: PhotoView(
          imageProvider: MemoryImage(imageBytes),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
          heroAttributes: const PhotoViewHeroAttributes(tag: "resultHero"),
        ),
      ),
    );
  }
}
