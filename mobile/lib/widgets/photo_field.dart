import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import 'common.dart';

/// Photo d'un article / d'une catégorie : aperçu + « Appareil photo » ou « Galerie ».
/// `imagePath` = image déjà enregistrée sur le serveur (chemin /storage/… ou URL).
class PhotoField extends StatelessWidget {
  const PhotoField({super.key, required this.file, required this.onChanged, this.imagePath, this.size = 140});

  final File? file;
  final String? imagePath;
  final ValueChanged<File?> onChanged;
  final double size;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
      if (x != null) onChanged(File(x.path));
    } catch (e) {
      if (context.mounted) showInfo(context, 'Impossible d’ouvrir ${source == ImageSource.camera ? 'l’appareil photo' : 'la galerie'}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = context.api.imageUrl(imagePath);
    Widget preview;
    if (file != null) {
      preview = Image.file(file!, fit: BoxFit.cover);
    } else if (url != null) {
      preview = Image.network(url, fit: BoxFit.contain, errorBuilder: (_, _, _) => const _Placeholder());
    } else {
      preview = const _Placeholder();
    }
    return Column(children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: preview,
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
        OutlinedButton.icon(
          onPressed: () => _pick(context, ImageSource.camera),
          icon: const Icon(Icons.photo_camera_outlined, size: 18),
          label: const Text('Appareil photo'),
        ),
        OutlinedButton.icon(
          onPressed: () => _pick(context, ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined, size: 18),
          label: const Text('Galerie'),
        ),
      ]),
    ]);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_a_photo_outlined, size: 36, color: AppColors.muted),
          SizedBox(height: 6),
          Text('Photo', style: TextStyle(color: AppColors.muted)),
        ]),
      );
}
