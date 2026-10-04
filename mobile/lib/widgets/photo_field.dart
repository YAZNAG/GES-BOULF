import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import 'common.dart';

/// Prend une photo (appareil ou galerie). Null si annulé ou impossible.
Future<File?> pickPhotoFile(BuildContext context, ImageSource source) async {
  try {
    final x = await ImagePicker().pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
    return x == null ? null : File(x.path);
  } catch (e) {
    if (context.mounted) showInfo(context, 'Impossible d’ouvrir ${source == ImageSource.camera ? 'l’appareil photo' : 'la galerie'}.');
    return null;
  }
}

enum PhotoAction { view, camera, gallery, remove }

/// Menu « photo » : voir, appareil photo, galerie, supprimer.
Future<PhotoAction?> askPhotoAction(BuildContext context, {required bool hasImage, String title = 'Photo'}) {
  return showModalBottomSheet<PhotoAction>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
        if (hasImage)
          ListTile(
            leading: const Icon(Icons.zoom_in),
            title: const Text('Voir en grand'),
            onTap: () => Navigator.pop(c, PhotoAction.view),
          ),
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text('Appareil photo'),
          onTap: () => Navigator.pop(c, PhotoAction.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Galerie'),
          onTap: () => Navigator.pop(c, PhotoAction.gallery),
        ),
        if (hasImage)
          ListTile(
            leading: const Icon(Icons.hide_image_outlined, color: AppColors.danger),
            title: const Text('Supprimer la photo', style: TextStyle(color: AppColors.danger)),
            onTap: () => Navigator.pop(c, PhotoAction.remove),
          ),
      ]),
    ),
  );
}

/// Photo d'un article / d'une catégorie : aperçu + « Appareil photo » ou « Galerie ».
/// `imagePath` = image déjà enregistrée sur le serveur (chemin /storage/… ou URL).
/// `onRemove` : affiche « Supprimer la photo » quand une image existe (le parent décide quoi faire).
class PhotoField extends StatelessWidget {
  const PhotoField({super.key, required this.file, required this.onChanged, this.imagePath, this.size = 140, this.onRemove});

  final File? file;
  final String? imagePath;
  final ValueChanged<File?> onChanged;
  final double size;
  final VoidCallback? onRemove;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final f = await pickPhotoFile(context, source);
    if (f != null) onChanged(f);
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
      if (onRemove != null && (file != null || url != null))
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: file != null ? () => onChanged(null) : onRemove,
          icon: const Icon(Icons.hide_image_outlined, size: 18),
          label: Text(file != null ? 'Retirer la nouvelle photo' : 'Supprimer la photo'),
        ),
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
