import 'package:image_picker/image_picker.dart';

class MediaPickerService {
  MediaPickerService._();

  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> pickFromGallery() async {
    return _picker.pickImage(source: ImageSource.gallery);
  }

  static Future<XFile?> pickFromCamera() async {
    return _picker.pickImage(source: ImageSource.camera);
  }
}
