#!/usr/bin/env python3
"""Synthesises the game's sound effects into godot/assets/sfx/*.wav (needs numpy).

Everything is generated from noise and oscillators, so there are no third-party recordings
to license. Run from anywhere:  python3 godot/tools/make_sounds.py
"""
import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")
rng = np.random.default_rng(7)


def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def noise(seconds):
    return rng.standard_normal(int(seconds * RATE))


def band(signal, low, high, soft=0.15):
    """Band-pass in the frequency domain with soft edges."""
    spectrum = np.fft.rfft(signal)
    f = np.fft.rfftfreq(len(signal), 1 / RATE)
    lo = 1 / (1 + np.exp(-(f - low) / (low * soft + 1)))
    hi = 1 / (1 + np.exp((f - high) / (high * soft + 1)))
    return np.fft.irfft(spectrum * lo * hi, len(signal))


def resonator(signal, freq, bandwidth):
    """Two-pole resonant filter, used for vowel formants."""
    r = np.exp(-np.pi * bandwidth / RATE)
    a1 = -2 * r * np.cos(2 * np.pi * freq / RATE)
    a2 = r * r
    gain = 1 - r
    out = np.zeros_like(signal)
    y1 = y2 = 0.0
    for i, x in enumerate(signal):
        y = gain * x - a1 * y1 - a2 * y2
        out[i] = y
        y2, y1 = y1, y
    return out


def envelope(n, attack, release, curve=4.0):
    env = np.ones(n)
    a = max(1, int(attack * RATE))
    r = max(1, int(release * RATE))
    env[:a] = np.linspace(0, 1, a)
    env[-r:] *= np.exp(-curve * np.linspace(0, 1, r))
    return env


def normalise(signal, peak=0.89):
    m = np.max(np.abs(signal))
    return signal if m == 0 else signal * (peak / m)


def save(name, signal):
    os.makedirs(OUT, exist_ok=True)
    data = (np.clip(signal, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print(f"{name}: {len(signal) / RATE:.2f}s")


def kick():
    t = t_axis(0.16)
    freq = 160 * np.exp(-t * 28) + 55
    body = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t * 26)
    click = band(noise(0.16), 1500, 6000) * np.exp(-t * 180) * 0.6
    return normalise(body + click, 0.95)


def bounce():
    t = t_axis(0.12)
    freq = 260 * np.exp(-t * 35) + 120
    body = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t * 40)
    knock = band(noise(0.12), 800, 3500) * np.exp(-t * 120) * 0.35
    return normalise(body + knock, 0.6)


def whistle(seconds, trill=28.0):
    t = t_axis(seconds)
    # The pea in a referee whistle chops the tone into a fast trill.
    trill_wave = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * trill * t)) * 0.9
    pitch = 2950 + 40 * np.sin(2 * np.pi * 5 * t)
    tone = np.sin(2 * np.pi * np.cumsum(pitch) / RATE)
    tone += 0.25 * np.sin(2 * np.pi * np.cumsum(pitch * 2) / RATE)
    breath = band(noise(seconds), 2000, 7000) * 0.12
    return (tone * trill_wave + breath) * envelope(len(t), 0.02, 0.08)


def crowd(seconds, excitement):
    """Many voices: band-limited noise with slow random swells per voice group."""
    n = int(seconds * RATE)
    out = np.zeros(n)
    t = t_axis(seconds)
    for low, high, gain in [(180, 900, 1.0), (500, 2200, 0.7), (1500, 4000, 0.25)]:
        voices = band(noise(seconds), low, high)
        swell = np.interp(t, np.linspace(0, seconds, 24), rng.uniform(0.6, 1.0, 24))
        out += voices * swell * gain
    return out * excitement


def chant_gol(seconds):
    """A crowd singing "Goooool": detuned voices through 'o' vowel formants."""
    t = t_axis(seconds)
    n = len(t)
    source = np.zeros(n)
    for i in range(18):
        base = rng.uniform(150, 260)
        # Pitch rises as the shout builds, with each voice's own wobble.
        pitch = base * (1 + 0.18 * np.clip(t / 0.6, 0, 1)) * (1 + 0.012 * np.sin(2 * np.pi * rng.uniform(4, 7) * t))
        phase = np.cumsum(pitch) / RATE + rng.uniform()
        saw = 2 * (phase % 1) - 1
        onset = rng.uniform(0, 0.12)
        source += saw * np.clip((t - onset) / 0.05, 0, 1)
    vowel = resonator(source, 480, 90) + 0.6 * resonator(source, 820, 110) + 0.18 * resonator(source, 2600, 180)
    # "G" at the start, "l" at the end (darker, quieter).
    g = band(noise(seconds), 300, 2500) * np.exp(-t * 60) * 2.0
    env = np.clip(t / 0.08, 0, 1) * np.where(t < seconds - 0.5, 1.0, np.exp(-(t - (seconds - 0.5)) * 5))
    return normalise(vowel * env + g, 0.8)


def air_horn(seconds):
    t = t_axis(seconds)
    out = np.zeros(len(t))
    for f, g in [(233.1, 1.0), (311.1, 0.8), (349.2, 0.6)]:
        phase = np.cumsum(np.full(len(t), f) * (1 + 0.003 * np.sin(2 * np.pi * 6 * t))) / RATE
        saw = 2 * (phase % 1) - 1
        out += saw * g
    out = band(out, 150, 3500)
    # Two short blasts and a long one.
    gate = np.zeros(len(t))
    for start, length in [(0.0, 0.22), (0.3, 0.22), (0.6, seconds - 0.7)]:
        a, b = int(start * RATE), int((start + length) * RATE)
        gate[a:b] = envelope(b - a, 0.015, 0.06)
    return normalise(out * gate, 0.7)


def goal():
    seconds = 5.0
    t = t_axis(seconds)
    roar = crowd(seconds, 1.0)
    swell = np.clip(t / 0.35, 0, 1) * np.where(t < 3.2, 1.0, np.exp(-(t - 3.2) * 1.4))
    roar = normalise(roar * swell, 0.55)
    mix = roar
    chant = chant_gol(2.4)
    start = int(0.35 * RATE)
    mix[start:start + len(chant)] += chant * 0.75
    horn = air_horn(1.6)
    start = int(0.05 * RATE)
    mix[start:start + len(horn)] += horn * 0.45
    return normalise(mix, 0.92)


def win():
    seconds = 4.5
    mix = np.zeros(int(seconds * RATE))
    for start, length in [(0.0, 0.35), (0.5, 0.35), (1.0, 1.1)]:
        w = whistle(length)
        a = int(start * RATE)
        mix[a:a + len(w)] += w * 0.6
    t = t_axis(seconds)
    cheer = normalise(crowd(seconds, 1.0) * np.clip((t - 1.0) / 0.4, 0, 1) * np.exp(-np.clip(t - 3.0, 0, None) * 1.5), 0.5)
    return normalise(mix + cheer, 0.9)


def crowd_loop():
    seconds = 8.0
    murmur = crowd(seconds + 1.0, 1.0)
    fade = int(1.0 * RATE)
    loop = murmur[:-fade].copy()
    # Crossfade the tail into the head so the loop has no seam.
    ramp = np.linspace(0, 1, fade)
    loop[:fade] = loop[:fade] * ramp + murmur[-fade:] * (1 - ramp)
    return normalise(loop, 0.35)


def click():
    t = t_axis(0.05)
    return normalise(np.sin(2 * np.pi * 1800 * t) * np.exp(-t * 120) + band(noise(0.05), 3000, 8000) * np.exp(-t * 300) * 0.3, 0.4)


if __name__ == "__main__":
    save("kick.wav", kick())
    save("bounce.wav", bounce())
    save("whistle.wav", normalise(whistle(0.45), 0.6))
    save("goal.wav", goal())
    save("win.wav", win())
    save("crowd_loop.wav", crowd_loop())
    save("click.wav", click())
