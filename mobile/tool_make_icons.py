"""Génère l'icône Android (mipmaps) et le logo d'écran de démarrage de Boulfrik."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).parent
RES = ROOT / "android/app/src/main/res"
FONT = next(p for p in [Path("C:/Windows/Fonts/segoeuib.ttf"), Path("C:/Windows/Fonts/arialbd.ttf")] if p.exists())


def logo(size: int, rounded: bool = True) -> Image.Image:
    s = 4  # suréchantillonnage pour des bords nets
    W = size * s
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    # Dégradé rouge de la marque
    grad = Image.new("RGBA", (W, W))
    px = ImageDraw.Draw(grad)
    top, bot = (244, 63, 94), (190, 18, 60)
    for y in range(W):
        t = y / (W - 1)
        px.line([(0, y), (W, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bot)) + (255,))
    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, W - 1], radius=int(W * (0.23 if rounded else 0)), fill=255)
    img.paste(grad, (0, 0), mask)
    # Panier stylisé (anse + corps) en blanc translucide, sur un calque fusionné
    layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    m = W * 0.2
    ld.arc([m + W * 0.12, W * 0.12, W - m - W * 0.12, W * 0.48], 200, 340, fill=(255, 255, 255, 170), width=int(W * 0.045))
    ld.rounded_rectangle([m, W * 0.33, W - m, W * 0.82], radius=int(W * 0.06), fill=(255, 255, 255, 55))
    img = Image.alpha_composite(img, layer)
    d = ImageDraw.Draw(img)
    # Lettre B
    font = ImageFont.truetype(str(FONT), int(W * 0.44))
    box = d.textbbox((0, 0), "B", font=font)
    tw, th = box[2] - box[0], box[3] - box[1]
    d.text(((W - tw) / 2 - box[0], W * 0.575 - th / 2 - box[1]), "B", font=font, fill=(255, 255, 255, 255))
    return img.resize((size, size), Image.LANCZOS)


for folder, px in {"mipmap-mdpi": 48, "mipmap-hdpi": 72, "mipmap-xhdpi": 96, "mipmap-xxhdpi": 144, "mipmap-xxxhdpi": 192}.items():
    (RES / folder).mkdir(parents=True, exist_ok=True)
    logo(px).save(RES / folder / "ic_launcher.png")

(RES / "drawable").mkdir(exist_ok=True)
logo(288).save(RES / "drawable/splash_logo.png")
logo(1024).save(ROOT / "assets/branding/icon-1024.png")
print("ok")
