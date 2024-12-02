import 'dart:typed_data';

import 'package:example/rename_picture_dialog.dart';
import 'package:example/take_picture.dart';
import 'package:face_api_web/face_api_web.dart';
import 'package:flutter/material.dart';

class FaceRef {
  final String name;
  final Uint8List image;
  final Face face;

  FaceRef(this.name, this.image, this.face);
}

class FacesRef {
  final List<FaceRef> faces;

  FacesRef(this.faces);
}

class FaceListPage extends StatefulWidget {
  final FacesRef faces;

  const FaceListPage({super.key, required this.faces});

  @override
  State<FaceListPage> createState() => _FaceListPageState();
}

class _FaceListPageState extends State<FaceListPage> {
  late List<FaceRef> _faces;

  @override
  void initState() {
    super.initState();
    _faces = widget.faces.faces;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              Navigator.of(context).pop(FacesRef(_faces));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) {
              return TakePicturePage();
            },
          )).then(
            (value) {
              if (value is TakePictureResult && context.mounted) {
                setState(() {
                  _faces.add(FaceRef(value.name, value.picture, value.face));
                });
              }
            },
          );
        },
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: _faces.length,
        itemBuilder: (context, index) {
          final face = _faces[index];
          return ListTile(
            leading: Image.memory(face.image, width: 48, height: 48),
            title: Text(face.name),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                setState(() {
                  _faces.removeAt(index);
                });
              },
            ),
            onTap: () {
              // rename
              showDialog(
                context: context,
                builder: (context) {
                  return RenamePictureDialog(
                      picture: face.image, name: face.name);
                },
              ).then(
                (result) {
                  if (result is String && context.mounted) {
                    setState(() {
                      _faces[index] = FaceRef(result, face.image, face.face);
                    });
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
