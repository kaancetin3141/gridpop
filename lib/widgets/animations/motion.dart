import 'package:flutter/material.dart';

/// Wraps a widget with a springy press animation. Used by every button in the
/// game so the whole UI reacts the same way.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.94,
    this.enabled = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool enabled;
  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      behavior: widget.behavior,
      onTap: active ? widget.onTap : null,
      onLongPress: active ? widget.onLongPress : null,
      onTapDown: active ? (_) => _setPressed(true) : null,
      onTapUp: active ? (_) => _setPressed(false) : null,
      onTapCancel: active ? () => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fades and slides a widget in the first time it is built. Used for lists and
/// hero elements.
class PopIn extends StatefulWidget {
  const PopIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.12),
    this.scale = 0.92,
  });

  final Widget child;
  final Duration delay;
  final Offset offset;
  final double scale;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CurvedAnimation curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: curve.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: widget.offset * (1 - curve.value),
            child: Transform.scale(
              scale: widget.scale + (1 - widget.scale) * curve.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Counts from the previous value to the new one whenever [value] changes.
class CountUpText extends StatefulWidget {
  const CountUpText({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 420),
    this.curve = Curves.easeOutCubic,
  });

  final int value;
  final Widget Function(BuildContext context, int value) builder;
  final Duration duration;
  final Curve curve;

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late int _from = widget.value;
  late int _displayed = widget.value;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_tick);
  }

  @override
  void didUpdateWidget(CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) {
      return;
    }
    _from = _displayed;
    _controller
      ..duration = widget.duration
      ..forward(from: 0);
  }

  void _tick() {
    final double t = Curves.easeOutCubic.transform(_controller.value);
    setState(() {
      _displayed = (_from + (widget.value - _from) * t).round();
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_tick)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _displayed);
}

/// Fades and slides children in sequence, used on the menu and settings lists.
class StaggeredColumn extends StatelessWidget {
  const StaggeredColumn({
    super.key,
    required this.children,
    this.spacing = 10,
    this.stagger = const Duration(milliseconds: 55),
  });

  final List<Widget> children;
  final double spacing;
  final Duration stagger;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: spacing),
          PopIn(
            key: ValueKey<int>(i),
            delay: stagger * i,
            child: children[i],
          ),
        ],
      ],
    );
  }
}