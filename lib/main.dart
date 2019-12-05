import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';

import 'package:flutter_native_image/flutter_native_image.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:palette_generator/palette_generator.dart';

void main() => runApp(MyApp());

const Color _kBackgroundColor = Color(0xffa0a0a0);
const Color _kSelectionRectangleBackground = Color(0x15000000);
const Color _kSelectionRectangleBorder = Color(0x80000000);
const Color _kPlaceholderColor = Color(0x80404040);

/// Classe principal da aplicação
class MyApp extends StatelessWidget {
  //Aqui se cria uma rota para a tela principal
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leitor de Imagem',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const ImageColors(
        title: 'Leitor de Imagem',
        image: AssetImage('image/boi 2.jpg'),
        imageSize: Size(255.0, 170.0),
      ),
    );
  }
}

/// Tela principal da aplicação.
@immutable
class ImageColors extends StatefulWidget {
  /// Cria a tela principal.
  const ImageColors({
    Key key,
    this.title,
    this.image,
    this.imageSize,
  }) : super(key: key);

  /// Titulo do topo da tela.
  final String title;

  /// Imagem recebida inicialmente
  final ImageProvider image;

  /// dimensão da imagem.
  final Size imageSize;

  @override
  _ImageColorsState createState() {
    return _ImageColorsState();
  }
}

class _ImageColorsState extends State<ImageColors> {
  Rect region;
  Rect dragRegion;
  Offset startDrag;
  Offset currentDrag;
  PaletteGenerator paletteGenerator;

  File imagem;
  bool isImageLoaded = false;

  final GlobalKey imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    region =
        Offset((widget.imageSize.width) / 4, (widget.imageSize.height) / 4) &
            Size((widget.imageSize.width) / 2, (widget.imageSize.height) / 2);
    _updatePaletteGenerator(region);
  }

  Future<void> _updatePaletteGenerator(Rect newRegion) async {
    paletteGenerator = await PaletteGenerator.fromImageProvider(
      isImageLoaded ? FileImage(imagem) : widget.image,
      size: widget.imageSize,
      region: newRegion,
      maximumColorCount: 18,
    );
    setState(() {});
  }

  // Metodo chamado quando se começa a arrastar o seletor da imagem
  void _onPanDown(DragDownDetails details) {
    final RenderBox box = imageKey.currentContext.findRenderObject();
    final Offset localPosition = box.globalToLocal(details.globalPosition);
    setState(() {
      startDrag = localPosition;
      currentDrag = startDrag;
      dragRegion = Rect.fromPoints(startDrag, currentDrag);
    });
  }

  // Metodo chamado quando se atualiza a posição do seletor.
  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      currentDrag += details.delta;
      dragRegion = Rect.fromPoints(startDrag, currentDrag);
    });
  }

  // chamado quando se cancela o seletor(ex rotacionando o app ou abrindo outro)
  void _onPanCancel() {
    setState(() {
      dragRegion = null;
      startDrag = null;
    });
  }

  // Chamado quando se termina de arrastar. Salva a região de arrasto e atualiza as cores.
  void _onPanEnd(DragEndDetails details) async {
    Rect newRegion =
        (Offset.zero & imageKey.currentContext.size).intersect(dragRegion);
    if (newRegion.size.width < 4 && newRegion.size.height < 4) {
      newRegion = Offset.zero & imageKey.currentContext.size;
    }
    await _updatePaletteGenerator(newRegion);
    setState(() {
      region = newRegion;
      dragRegion = null;
      startDrag = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackgroundColor,
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.photo_camera),
        onPressed: () async {
          var tempStore =
              await ImagePicker.pickImage(source: ImageSource.camera);

          File compressedFile = await FlutterNativeImage.compressImage(
              tempStore.path,
              quality: 100,
              targetWidth: widget.imageSize.width.toInt(),
              targetHeight: widget.imageSize.height.toInt());

          setState(() {
            imagem = compressedFile;
            isImageLoaded = true;
            region = Offset((widget.imageSize.width) / 4,
                    (widget.imageSize.height) / 4) &
                Size((widget.imageSize.width) / 2,
                    (widget.imageSize.height) / 2);
            _updatePaletteGenerator(region);
          });
        },
      ),
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(20.0),
            // GestureDetector é usado para fazer um seletor retangular.
            child: GestureDetector(
              onPanDown: _onPanDown,
              onPanUpdate: _onPanUpdate,
              onPanCancel: _onPanCancel,
              onPanEnd: _onPanEnd,
              child: Stack(children: <Widget>[
                Image(
                  key: imageKey,
                  image: isImageLoaded ? FileImage(imagem) : widget.image,
                  width: widget.imageSize.width,
                  height: widget.imageSize.height,
                ),

                // Esse é o retangulo utilizado
                Positioned.fromRect(
                    rect: dragRegion ?? region ?? Rect.zero,
                    child: Container(
                      decoration: BoxDecoration(
                          color: _kSelectionRectangleBackground,
                          border: Border.all(
                            width: 1.0,
                            color: _kSelectionRectangleBorder,
                            style: BorderStyle.solid,
                          )),
                    )),
              ]),
            ),
          ),
          // Use um FutureBuilder para que as paletas sejam exibidas quando o gerador de paletas terminar de gerar seus dados.
          PaletteSwatches(generator: paletteGenerator),
        ],
      ),
    );
  }
}

/// A widget that draws the swatches for the [PaletteGenerator] it is given,
/// and shows the selected target colors.
class PaletteSwatches extends StatelessWidget {
  /// Create a Palette swatch.
  ///
  /// The [generator] is optional. If it is null, then the display will
  /// just be an empty container.
  const PaletteSwatches({Key key, this.generator}) : super(key: key);

  /// The [PaletteGenerator] that contains all of the swatches that we're going
  /// to display.
  final PaletteGenerator generator;

  @override
  Widget build(BuildContext context) {
    final List<Widget> swatches = <Widget>[];
    if (generator == null || generator.colors.isEmpty) {
      return Container();
    }
    for (Color color in generator.colors) {
      swatches.add(PaletteSwatch(color: color));
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Wrap(
          children: swatches,
        ),
        Container(height: 30.0),
        PaletteSwatch(
            label: 'Dominante', color: generator.dominantColor?.color),
        PaletteSwatch(
            label: 'Claro e Vibrante', color: generator.lightVibrantColor?.color),
        PaletteSwatch(label: 'Vibrante', color: generator.vibrantColor?.color),
        PaletteSwatch(
            label: 'Escura e Vibrante', color: generator.darkVibrantColor?.color),
        PaletteSwatch(
            label: ' Muted Clara', color: generator.lightMutedColor?.color),
        PaletteSwatch(label: ' Muted', color: generator.mutedColor?.color),
        PaletteSwatch(
            label: ' Muted Escura', color: generator.darkMutedColor?.color),
      ],
    );
  }
}

/// A small square of color with an optional label.
@immutable
class PaletteSwatch extends StatelessWidget {
  /// Creates a PaletteSwatch.
  ///
  /// If the [color] argument is omitted, then the swatch will show a
  /// placeholder instead, to indicate that there is no color.
  const PaletteSwatch({
    Key key,
    this.color,
    this.label,
  }) : super(key: key);

  /// The color of the swatch. May be null.
  final Color color;

  /// The optional label to display next to the swatch.
  final String label;

  @override
  Widget build(BuildContext context) {
    // Compute the "distance" of the color swatch and the background color
    // so that we can put a border around those color swatches that are too
    // close to the background's saturation and lightness. We ignore hue for
    // the comparison.
    final HSLColor hslColor = HSLColor.fromColor(color ?? Colors.transparent);
    final HSLColor backgroundAsHsl = HSLColor.fromColor(_kBackgroundColor);
    final double colorDistance = math.sqrt(
        math.pow(hslColor.saturation - backgroundAsHsl.saturation, 2.0) +
            math.pow(hslColor.lightness - backgroundAsHsl.lightness, 2.0));

    Widget swatch = Padding(
      padding: const EdgeInsets.all(2.0),
      child: color == null
          ? const Placeholder(
              fallbackWidth: 34.0,
              fallbackHeight: 20.0,
              color: Color(0xff404040),
              strokeWidth: 2.0,
            )
          : Container(
              decoration: BoxDecoration(
                  color: color,
                  border: Border.all(
                    width: 1.0,
                    color: _kPlaceholderColor,
                    style: colorDistance < 0.2
                        ? BorderStyle.solid
                        : BorderStyle.none,
                  )),
              width: 34.0,
              height: 20.0,
            ),
    );

    if (label != null) {
      swatch = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180.0, minWidth: 130.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            swatch,
            Container(width: 5.0),
            Text(label),
          ],
        ),
      );
    }
    return swatch;
  }
}
