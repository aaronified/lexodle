import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'geography.dart';
import 'ui.dart';

/// The small round "i" to the right of a guess of the themed wordle: it opens
/// what the place is.
class PlaceDot extends StatelessWidget {
  const PlaceDot(this.place, {super.key});
  final Place place;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    return Semantics(
      button: true,
      label: 'about ${place.name}',
      child: GestureDetector(
        onTap: () => showPlaceInfo(context, place),
        child: Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: dim, width: 1.5),
          ),
          child: Text(
            'i',
            style: TextStyle(
              fontSize: 12,
              height: 1,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold,
              color: dim,
            ),
          ),
        ),
      ),
    );
  }
}

/// What a place is: its kind and country, and a link to its page on Wikipedia.
void showPlaceInfo(BuildContext context, Place place) {
  final c = Theme.of(context).colorScheme;
  showHairlineDialog<void>(
    context,
    title: place.name.toLowerCase(),
    children: [
      Text(
        [place.kind, if (place.country.isNotEmpty) place.country].join(' · '),
        key: const ValueKey('place-kind'),
        style: TextStyle(fontSize: 13, color: c.primary),
      ),
      const SizedBox(height: 8),
      Text(
        'a place name in the geography theme.',
        style: TextStyle(
          fontSize: 11,
          color: c.onSurface.withValues(alpha: dimAlpha),
        ),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          key: const ValueKey('place-link'),
          onTap: () => launchUrl(place.link),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'read about ${place.name.toLowerCase()} on wikipedia',
              style: TextStyle(
                fontSize: 12,
                color: c.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
