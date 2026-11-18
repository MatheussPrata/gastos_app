import 'dart:async';

import 'package:flutter/widgets.dart';

/// Adia a construcao de um trecho pesado para depois do primeiro frame.
///
/// Evita que consultas secundarias (cartoes, planejamento, permissoes)
/// atrasem a abertura do app. O conteudo aparece suavemente logo depois.
class Deferred extends StatefulWidget {
  const Deferred({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 700),
  });

  final Widget child;
  final Duration delay;

  @override
  State<Deferred> createState() => _DeferredState();
}

class _DeferredState extends State<Deferred> {
  Timer? _timer;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _show ? widget.child : const SizedBox.shrink();
  }
}
