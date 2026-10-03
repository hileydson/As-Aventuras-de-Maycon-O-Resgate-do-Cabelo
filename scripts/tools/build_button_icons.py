"""Gera os icones de botao que faltavam no pause reaproveitando os existentes.

As teclas novas saem do molde de Q_Key_Light.png e o ombro esquerdo sai de
rb_xbox.png, mantendo cores, molduras e tamanhos do pacote original.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
BUTTONS = ROOT / 'assets/novas_imagens/buttons'
FONT_PATH = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

KEY_TEMPLATE = BUTTONS / 'Q_Key_Light.png'
KEY_FACE = (24, 24, 76, 76)
KEY_FACE_COLOR = (245, 245, 245, 255)
KEY_GLYPH_COLOR = (64, 64, 64, 255)
NEW_KEYS = {'V': 'V_Key_Light.png', 'F': 'F_Key_Light.png'}

SHOULDER_TEMPLATE = BUTTONS / 'rb_xbox.png'
SHOULDER_TEXT_BOX = (42, 40, 80, 63)
SHOULDER_BODY_COLOR = (102, 102, 102, 255)
SHOULDER_GLYPH_COLOR = (154, 154, 154, 255)


def centered(draw, box, text, font, color):
    left, top, right, bottom = box
    bounds = draw.textbbox((0, 0), text, font=font)
    x = left + (right - left - (bounds[2] - bounds[0])) * 0.5 - bounds[0]
    y = top + (bottom - top - (bounds[3] - bounds[1])) * 0.5 - bounds[1]
    draw.text((x, y), text, font=font, fill=color)


def build_keys():
    for letter, name in NEW_KEYS.items():
        image = Image.open(KEY_TEMPLATE).convert('RGBA')
        draw = ImageDraw.Draw(image)
        draw.rectangle(KEY_FACE, fill=KEY_FACE_COLOR)
        centered(draw, KEY_FACE, letter, ImageFont.truetype(FONT_PATH, 46), KEY_GLYPH_COLOR)
        image.save(BUTTONS / name)
        print('wrote', name)


def build_left_shoulder():
    image = Image.open(SHOULDER_TEMPLATE).convert('RGBA')
    draw = ImageDraw.Draw(image)
    draw.rectangle(SHOULDER_TEXT_BOX, fill=SHOULDER_BODY_COLOR)
    centered(draw, SHOULDER_TEXT_BOX, 'LB', ImageFont.truetype(FONT_PATH, 26), SHOULDER_GLYPH_COLOR)
    image.save(BUTTONS / 'lb_xbox.png')
    print('wrote lb_xbox.png')


build_keys()
build_left_shoulder()
