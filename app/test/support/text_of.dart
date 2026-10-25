import 'package:flutter/widgets.dart';

/// The text of a [Text], whether it was given plain or as spans (a line with
/// a measure's term in colour is a [Text.rich]).
String? textOf(Text t) => t.data ?? t.textSpan?.toPlainText();
