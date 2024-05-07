import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Texture, Image;
import 'package:image/image.dart' hide Color;
import 'package:path/path.dart' as path;
import 'package:retro/otr/resource.dart';
import 'package:retro/otr/resource_type.dart';
import 'package:retro/otr/types/background.dart';
import 'package:retro/otr/types/texture.dart';
import 'package:retro/ui/components/custom_scaffold.dart';

class DebugGeneratorFontsScreen extends StatefulWidget {
  const DebugGeneratorFontsScreen({super.key});

  @override
  State<DebugGeneratorFontsScreen> createState() =>
      _DebugGeneratorFontsScreenState();
}

class _DebugGeneratorFontsScreenState extends State<DebugGeneratorFontsScreen> {
  TextureType selectedTextureType = TextureType.RGBA32bpp;
  Texture? textureData;
  File? textureFile;

  Uint8List? textureBytes;

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      title: 'Debug Convert Textures',
      subtitle: 'Convert and preview textures',
      onBackButtonPressed: () {
        Navigator.of(context).pop();
      },
      content: Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'PNG to N64 Viewer',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'GoogleSans',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF40aae8),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: DropdownButton(
                      value: selectedTextureType,
                      icon: const Icon(Icons.arrow_drop_down_rounded),
                      borderRadius: BorderRadius.circular(5),
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'GoogleSans',
                        fontWeight: FontWeight.bold,
                      ),
                      dropdownColor: const Color(0xFF40aae8),
                      underline: Container(),
                      items: TextureType.values
                          .sublist(1)
                          .map<DropdownMenuItem>(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 17),
                                child: Text(e.name),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (_) {
                        setState(() {
                          selectedTextureType = _ as TextureType;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 250),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          textureFile == null
                              ? 'Select Texture File'
                              : textureFile!.path.split(path.separator).last,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                      );
                      if (result != null) {
                        setState(() {
                          textureFile = File(result.files.single.path!);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    child: const Text('Convert Texture'),
                    onPressed: () {
                      if (textureFile != null) {
                        setState(() async {
                          textureData = Texture.empty();
                          textureData?.textureType = selectedTextureType;
                          final image =
                              decodePng(await textureFile!.readAsBytes())!;
                          textureData!.fromRawImage(image);
                          if (selectedTextureType.name.contains('Palette')) {
                            textureData!.isPalette = true;
                          }
                          textureBytes = await textureData!.toPNGBytes();
                        });
                      }
                    },
                  ),
                  if (textureData != null && textureData!.isPalette)
                    const SizedBox(height: 20),
                  if (textureData != null && textureData!.isPalette)
                    ElevatedButton(
                      child: const Text('Load TLUT'),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                        );
                        if (result != null) {
                          setState(() async {
                            final tlut = Texture.empty()
                              ..textureType = TextureType.RGBA32bpp;
                            final image = decodePng(
                              await File(result.files.single.path!)
                                  .readAsBytes(),
                            )!;
                            tlut.fromRawImage(image);
                            textureData!.tlut = tlut;
                            textureBytes = await textureData!.toPNGBytes();
                          });
                        }
                      },
                    ),
                  if (textureData != null && textureData!.tlut != null)
                    const SizedBox(height: 20),
                  if (textureData != null && textureData!.tlut != null)
                    ElevatedButton(
                      child: const Text('Save As'),
                      onPressed: () async {
                        final result = await FilePicker.platform.saveFile(
                          type: FileType.image,
                          allowedExtensions: ['png'],
                          fileName: 'converted.png',
                        );
                        if (result != null) {
                          setState(() async {
                            final out = File(result);
                            await out.writeAsBytes(textureBytes!);
                          });
                        }
                      },
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'OTR N64 Viewer',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'GoogleSans',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 250),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          textureFile == null
                              ? 'Select Texture File'
                              : textureFile!.path.split(path.separator).last,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles();
                      if (result != null) {
                        setState(() {
                          textureFile = File(result.files.single.path!);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    child: const Text('Load Texture'),
                    onPressed: () async {
                      if (textureFile != null) {
                        final bytes = await textureFile!.readAsBytes();

                        setState(() async {
                          final resource = Resource.empty()
                            ..rawLoad = true
                            ..open(bytes);

                          if (resource.resourceType == ResourceType.texture) {
                            textureData = Texture.empty();
                            textureData?.open(bytes);
                            textureBytes = await textureData!.toPNGBytes();
                          } else {
                            final background = Background.empty()..open(bytes);
                            textureData = Texture.empty();
                            textureBytes = background.texData;
                          }
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                height: MediaQuery.of(context).size.height - 119,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  image: textureData != null
                      ? DecorationImage(
                          image: MemoryImage(textureBytes!),
                          filterQuality: FilterQuality.none,
                          fit: BoxFit.contain,
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
