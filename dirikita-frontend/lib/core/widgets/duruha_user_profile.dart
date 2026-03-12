import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duruha/supabase_config.dart';
import 'package:duruha/core/constants/color_marker.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';

class DuruhaUserProfile extends StatefulWidget {
  final String? imageUrl;
  final String? userName;
  final double radius;
  final bool allowUpload;
  final String bucketName;
  final ValueChanged<String>? onImageUploaded;

  const DuruhaUserProfile({
    super.key,
    this.imageUrl,
    this.userName,
    this.radius = 40.0,
    this.allowUpload = false,
    this.bucketName = 'avatars',
    this.onImageUploaded,
  });

  @override
  State<DuruhaUserProfile> createState() => _DuruhaUserProfileState();
}

class _DuruhaUserProfileState extends State<DuruhaUserProfile> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndUploadImage() async {
    if (!widget.allowUpload || _isUploading) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      File fileToUpload = File(image.path);
      final int fileSize = await fileToUpload.length();

      int quality = 80;
      if (fileSize > 5 * 1024 * 1024) {
        // over 5 MB
        quality = 50;
      }

      final String basePath = image.path.contains('.')
          ? image.path.substring(0, image.path.lastIndexOf('.'))
          : image.path;
      final String targetPath = '${basePath}_comp.webp';

      final XFile? compressedFile =
          await FlutterImageCompress.compressAndGetFile(
            fileToUpload.absolute.path,
            targetPath,
            quality: quality,
            format: CompressFormat.webp,
          );

      if (compressedFile != null) {
        fileToUpload = File(compressedFile.path);
      }

      final fileName = 'avatar.webp';
      final userId = supabase.auth.currentUser?.id ?? 'unknown';
      final filePath = '$userId/$fileName';

      // Ensure the user doesn't upload duplicate file names and it stays organized
      await supabase.storage
          .from(widget.bucketName)
          .upload(
            filePath,
            fileToUpload,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final String publicUrl = supabase.storage
          .from(widget.bucketName)
          .getPublicUrl(filePath);

      if (widget.onImageUploaded != null) {
        widget.onImageUploaded!(publicUrl);
      }

      if (mounted) {
        DuruhaSnackBar.showSuccess(
          context,
          'Profile picture updated successfully!',
        );
      }
    } catch (error) {
      debugPrint('Error uploading image: $error');
      if (mounted) {
        DuruhaSnackBar.showError(context, 'Failed to upload image: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage =
        widget.imageUrl != null && widget.imageUrl!.isNotEmpty;

    // Pick a color from colorMarker based on the name's hash for consistency
    final int colorIndex = widget.userName != null
        ? widget.userName.hashCode.abs() % colorMarker.length
        : 0;
    final Color placeholderColor = colorMarker[colorIndex];
    final String initial = widget.userName?.isNotEmpty == true
        ? widget.userName![0].toUpperCase()
        : '?';
    late final theme = Theme.of(context);

    return GestureDetector(
      onTap: widget.allowUpload ? _pickAndUploadImage : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: widget.radius,
            backgroundColor: hasImage
                ? theme.colorScheme.primary
                : placeholderColor,
            backgroundImage: hasImage ? NetworkImage(widget.imageUrl!) : null,
            child: !hasImage
                ? Text(
                    initial,
                    style: TextStyle(
                      fontSize: widget.radius * 0.8,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : null,
          ),
          if (_isUploading)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          if (widget.allowUpload && !_isUploading)
            Positioned(
              bottom: 0,
              right: 0,
              child: Opacity(
                opacity: hasImage ? .5 : 1,
                child: Container(
                  padding: EdgeInsets.all(widget.radius * 0.1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.onPrimary,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: widget.radius * 0.3,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
