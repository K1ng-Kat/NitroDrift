# Real-world night environment lighting (CC0)

The photographic source is Poly Haven's Shanghai Bund HDRI by Greg Zaal:
https://polyhaven.com/a/shanghai_bund

License: CC0 1.0 (assets may be used commercially). An automated GitHub
workflow downloads the official 1K Radiance HDR and tone maps it into an
iPhone-friendly 8-bit JPEG called night_city.jpg.

The runtime uses this as an image-based lighting probe for glossy materials;
it retains NitroDrift's procedural city sky background. A tone-mapped JPG is
not a full multi-EV HDR light probe — it increases realism of captured urban
highlights, but does not deliver fully physical dynamic-range reflection.
