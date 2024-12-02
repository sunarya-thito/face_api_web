import 'dart:typed_data';

import 'package:flutter/material.dart';

class RenamePictureDialog extends StatefulWidget {
  final Uint8List picture;
  final String name;

  const RenamePictureDialog(
      {super.key, required this.picture, required this.name});

  @override
  State<RenamePictureDialog> createState() => _RenamePictureDialogState();
}

class _RenamePictureDialogState extends State<RenamePictureDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Picture'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.memory(widget.picture),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Name',
            ),
            controller: _nameController,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_nameController.text);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
