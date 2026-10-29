import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/recap_ending_messages.dart';

const recapEndingEarthAsset = 'assets/images/earth_equirectangular.png';
const recapEndingMoonAsset = 'assets/images/moon_equirectangular.png';
const recapEndingRotationDuration = Duration(seconds: 60);
// 北緯75°〜南緯75°の帯域を表示（150° / 180°）
const recapEndingLatitudeCrop = 150 / 180;
const recapEndingInertiaFriction = 3.5;
const recapEndingInertiaStopThreshold = 0.005;

String recapEndingAssetFor(RecapEndingBody body) {
  return switch (body) {
    RecapEndingBody.earth => recapEndingEarthAsset,
    RecapEndingBody.moon => recapEndingMoonAsset,
  };
}

double recapEndingWrappedSpin(double spin) {
  final wrapped = spin % 1.0;
  return wrapped < 0 ? wrapped + 1.0 : wrapped;
}

class RecapEndingEarth extends StatefulWidget {
  const RecapEndingEarth({
    super.key,
    this.body = RecapEndingBody.earth,
    this.size = 320,
    this.opacity = 0.55,
    this.rotationController,
  });

  final RecapEndingBody body;
  final double size;
  final double opacity;
  final AnimationController? rotationController;

  @override
  State<RecapEndingEarth> createState() => _RecapEndingEarthState();
}

class _RecapEndingEarthState extends State<RecapEndingEarth>
    with TickerProviderStateMixin {
  AnimationController? _ownedController;
  late final AnimationController _controller;
  late final Ticker _inertiaTicker;

  double _dragLongitude = 0;
  double _velocityLongitude = 0;
  Duration? _lastInertiaTick;

  @override
  void initState() {
    super.initState();
    _inertiaTicker = createTicker(_tickInertia);
    if (widget.rotationController != null) {
      _controller = widget.rotationController!;
      return;
    }

    _ownedController = AnimationController(
      vsync: this,
      duration: recapEndingRotationDuration,
    )..repeat();
    _controller = _ownedController!;
  }

  @override
  void dispose() {
    _inertiaTicker.dispose();
    _ownedController?.dispose();
    super.dispose();
  }

  void _stopInertia() {
    _inertiaTicker.stop();
    _lastInertiaTick = null;
    _velocityLongitude = 0;
    _normalizeDragLongitude();
  }

  void _normalizeDragLongitude() {
    _dragLongitude =
        recapEndingWrappedSpin(_controller.value + _dragLongitude) -
        _controller.value;
  }

  void _onPanStart(DragStartDetails details) {
    _stopInertia();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final mapWidth = widget.size * 2;
    setState(() {
      _dragLongitude -= details.delta.dx / mapWidth;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final mapWidth = widget.size * 2;
    _velocityLongitude = -details.velocity.pixelsPerSecond.dx / mapWidth;

    if (_velocityLongitude.abs() < recapEndingInertiaStopThreshold) {
      _normalizeDragLongitude();
      return;
    }

    _lastInertiaTick = null;
    _inertiaTicker.start();
  }

  void _tickInertia(Duration elapsed) {
    final dt =
        _lastInertiaTick == null
            ? 0.0
            : (elapsed - _lastInertiaTick!).inMicroseconds / 1e6;
    _lastInertiaTick = elapsed;
    if (dt <= 0) {
      return;
    }

    _dragLongitude += _velocityLongitude * dt;

    final decay = exp(-recapEndingInertiaFriction * dt);
    _velocityLongitude *= decay;

    if (_velocityLongitude.abs() < recapEndingInertiaStopThreshold) {
      _stopInertia();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mapWidth = widget.size * 2;
    final asset = recapEndingAssetFor(widget.body);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Opacity(
        opacity: widget.opacity,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: ClipOval(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final displaySpin = recapEndingWrappedSpin(
                  _controller.value + _dragLongitude,
                );
                final horizontalOffset = displaySpin * mapWidth;

                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: -horizontalOffset,
                      top: 0,
                      width: mapWidth,
                      height: widget.size,
                      child: child!,
                    ),
                    Positioned(
                      left: -horizontalOffset + mapWidth,
                      top: 0,
                      width: mapWidth,
                      height: widget.size,
                      child: child!,
                    ),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.16),
                              Colors.black.withValues(alpha: 0.52),
                            ],
                            stops: const [0.48, 0.8, 1],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              child: _MapTile(
                asset: asset,
                width: mapWidth,
                height: widget.size,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapTile extends StatelessWidget {
  const _MapTile({
    required this.asset,
    required this.width,
    required this.height,
  });

  final String asset;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: OverflowBox(
          maxHeight: height / recapEndingLatitudeCrop,
          minHeight: height / recapEndingLatitudeCrop,
          alignment: Alignment.center,
          child: Image.asset(
            asset,
            width: width,
            height: height / recapEndingLatitudeCrop,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
