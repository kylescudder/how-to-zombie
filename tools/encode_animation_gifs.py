#!/usr/bin/env python3
"""Encode the game's unedited frame captures. Requires Pillow; see README.
Run after tools/godot --fixed-fps 20 -- --solo --test=animations.
"""
from pathlib import Path
import argparse
import re
from PIL import Image


def encode(source: Path, destination: Path, fps: int, match: str, width: int) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    for clip in sorted(source.iterdir()):
        if not re.search(match, clip.name):
            continue
        files = sorted(clip.glob('*.png')) if clip.is_dir() else []
        if not files:
            continue
        samples = files[::max(1, len(files) // 9)][:9]
        sheet = Image.new('RGB', (320, 180 * len(samples)))
        for index, file in enumerate(samples):
            with Image.open(file) as original:
                sheet.paste(original.convert('RGB').resize((320, 180)), (0, index * 180))
        palette = sheet.quantize(colors=256)
        frames = []
        for file in files:
            with Image.open(file) as original:
                rgb = original.convert('RGB')
                if rgb.width != width:
                    rgb = rgb.resize((width, round(rgb.height * width / rgb.width)), Image.Resampling.LANCZOS)
                frames.append(rgb.quantize(palette=palette, dither=Image.Dither.NONE))
        output = destination / (clip.name + '.gif')
        frames[0].save(output, save_all=True, append_images=frames[1:], duration=round(1000 / fps),
                       loop=0, optimize=True, disposal=1)
        with Image.open(output) as gif:
            duration = sum(gif.seek(i) or gif.info.get('duration', 0) for i in range(gif.n_frames))
            assert duration > 0 and gif.n_frames > 1, f'{output} is not animated'
            print(f'{output}: {gif.n_frames} frames, {duration}ms, {output.stat().st_size:,} bytes', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path('screenshots/animations/frames'))
    parser.add_argument('--output', type=Path, default=Path('screenshots/animations/gifs'))
    parser.add_argument('--fps', type=int, default=20)
    parser.add_argument('--width', type=int, default=800, help='Output width, preserving aspect ratio')
    parser.add_argument('--match', default='.*', help='Regular expression selecting clip names')
    args = parser.parse_args()
    if args.fps <= 0:
        parser.error('--fps must be positive')
    encode(args.source, args.output, args.fps, args.match, args.width)
