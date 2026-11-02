"""Validate asset variants and semantic sRGB contrast without launching iOS.

This checks token pairs, not rendered layouts, opacity effects, or VoiceOver.
Run: python3 scripts/check_design_system.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'ios/local_dependencies/Prism/Sources/Prism/Resources/Colors.xcassets'
VARIANTS = {(), (('luminosity', 'dark'),), (('contrast', 'high'),),
            (('contrast', 'high'), ('luminosity', 'dark'))}
TEXT_PAIRS = [
    ('DSTextPrimary', 'DSCanvas'), ('DSTextPrimary', 'DSSurface'),
    ('DSTextSecondary', 'DSCanvas'), ('DSTextSecondary', 'DSSurface'),
    ('DSTextSecondary', 'DSElevated'), ('DSAccent', 'DSCanvas'),
    ('DSAccent', 'DSSurface'), ('DSAccent', 'DSAccentSurface'),
    ('DSOnAccent', 'DSAccent'), ('DSOnDanger', 'DSDanger'),
] + [(f'DS{tone}', f'DS{tone}Surface') for tone in ('Info', 'Success', 'Warning', 'Danger')]


def luminance(color):
    channels = [float(color['components'][key]) for key in ('red', 'green', 'blue')]
    assert all(0 <= channel <= 1 for channel in channels)
    assert float(color['components']['alpha']) == 1
    linear = [c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in channels]
    return sum(c * weight for c, weight in zip(linear, (.2126, .7152, .0722)))


colors = {}
for path in ASSETS.glob('*.colorset/Contents.json'):
    entries = json.loads(path.read_text())['colors']
    parsed = {}
    for entry in entries:
        key = tuple(sorted((a['appearance'], a['value']) for a in entry.get('appearances', [])))
        assert key not in parsed, f'Duplicate variant: {path}'
        parsed[key] = luminance(entry['color'])
    assert set(parsed) == VARIANTS, f'Missing light/dark/contrast variant: {path}'
    colors[path.parent.stem] = parsed

checks = 0
for foreground, background, minimum in [(*pair, 4.5) for pair in TEXT_PAIRS] + [('DSBorder', 'DSSurface', 3.0)]:
    for variant in VARIANTS:
        a, b = colors[foreground][variant], colors[background][variant]
        ratio = (max(a, b) + .05) / (min(a, b) + .05)
        assert ratio >= minimum, f'{foreground}/{background} {variant}: {ratio:.2f} < {minimum}'
        checks += 1
print(f'Validated {len(colors)} color assets, four variants each, and {checks} contrast pairs.')
