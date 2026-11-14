# Place names

The place names of the geography mode come from [GeoNames](https://www.geonames.org/)
(geonames.org), which is licensed under
[Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/). They are
filtered to countries, regions, cities of 15,000 people or more, and named features of land and
water, by `tools/build_geography.py`; names are reduced to the letters a to z.

How well known a place is comes from the number of views of its page on English Wikipedia in one
day (the public page-view counts of the Wikimedia Foundation, CC0). The info dot of a place links to
its Wikipedia page, which is opened by the player's browser.

## Land outline

`land-110m.json` is the Natural Earth land layer (110m, public domain) as TopoJSON from the npm package world-atlas (ISC). It draws the locator map of a place at the end of a geography game, offline.
