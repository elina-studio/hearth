"""Generate Hearth's ambiance loops procedurally (no samples, so no licensing questions).

    python3 tools/ambiance/sounds.py out_dir [seconds] [sample_rate] [suffix]

Writes fire.wav, rain.wav, night.wav (mono) that loop seamlessly: every filter is circular
and every event wraps around the end, so the last sample runs straight into the first.
Encode with ffmpeg afterwards (see build.sh).
"""
import sys, os, wave
import numpy as np

SR = 44100
LEN = 60.0
XF = 3.0  # crossfade used to close the loop
rng = np.random.default_rng(7)


def n_samples(sec):
    return int(sec * SR)


def band(x, lo=None, hi=None, slope=None):
    """Brick-ish FFT band filter with soft edges."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    g = np.ones_like(f)
    if lo:
        g *= 1 / (1 + (lo / np.maximum(f, 1e-3)) ** 4)
    if hi:
        g *= 1 / (1 + (f / hi) ** 4)
    if slope is not None:  # dB per octave tilt relative to 1 kHz
        g *= (np.maximum(f, 20) / 1000.0) ** (slope / 6.02)
    return np.fft.irfft(X * g, len(x))


def noise(n):
    return rng.standard_normal(n)


def norm(x, peak=1.0):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def slow(n, rate, depth, base=1.0):
    """A smooth random envelope (sum of slow sines), periodic over the loop."""
    t = np.arange(n) / SR
    e = np.zeros(n)
    for k in range(1, 6):
        # integer cycles per loop so it repeats cleanly
        cyc = max(1, int(round(rate * LEN * k * (0.6 + 0.8 * rng.random()))))
        e += np.sin(2 * np.pi * cyc * t / LEN + rng.random() * 6.28) / k
    e = e / np.max(np.abs(e))
    return base + depth * e


def add_at(buf, start, sig):
    """Add sig into buf, wrapping around the end so events near the seam loop too."""
    n = len(buf)
    s = start % n
    end = s + len(sig)
    if end <= n:
        buf[s:end] += sig
    else:
        k = n - s
        buf[s:] += sig[:k]
        buf[: end - n] += sig[k:]


def reverb(x, sec=0.35, mix=0.18):
    m = n_samples(sec)
    ir = noise(m) * np.exp(-np.arange(m) / (m / 5))
    ir = band(ir, 300, 6000)
    ir /= np.sqrt(np.sum(ir ** 2))
    n = len(x)
    L = 1 << int(np.ceil(np.log2(n + m)))
    wet = np.fft.irfft(np.fft.rfft(x, L) * np.fft.rfft(ir, L), L)
    # wrap the tail back to the start: the loop stays seamless
    w = wet[:n].copy()
    w[: len(wet) - n] += wet[n:]
    return x * (1 - mix) + w[:n] * mix * 3


def save(path, x, rms_db=-21.0):
    # even loudness across moods, peaks softly limited
    x = x / np.sqrt(np.mean(x ** 2)) * 10 ** (rms_db / 20)
    x = np.tanh(x * 1.2) / 1.2
    pcm = (x * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


# ---------------- fire ----------------
def fire():
    n = n_samples(LEN)
    t = np.arange(n) / SR
    rumble = band(noise(n), 40, 260) * slow(n, 0.15, 0.35)
    roar = band(noise(n), 150, 900, slope=-3) * slow(n, 0.4, 0.5) * 0.35
    hiss = band(noise(n), 2500, 9000) * slow(n, 1.2, 0.6) * 0.05
    out = rumble * 0.9 + roar + hiss
    out = norm(out, 0.22)
    cr = np.zeros(n)
    # crackles come in little clusters, like real wood
    tt = 0.0
    while tt < LEN:
        tt += rng.exponential(0.32)
        burst = rng.integers(1, 6)
        bt = tt
        for _ in range(burst):
            bt += rng.exponential(0.035)
            dur = rng.uniform(0.002, 0.012)
            dec = rng.uniform(0.003, 0.02)
            m = n_samples(dur + dec * 6)
            e = noise(m)
            fc = rng.uniform(900, 6000)
            e = band(e, fc * 0.5, fc * 1.6)
            env = np.exp(-np.arange(m) / (dec * SR))
            env[: n_samples(0.0006)] *= np.linspace(0, 1, n_samples(0.0006))
            amp = rng.lognormal(-1.6, 0.7)
            add_at(cr, n_samples(bt), e * env / (np.max(np.abs(e)) + 1e-9) * amp)
    # a few bigger pops with some body
    for _ in range(int(LEN * 0.25)):
        at = rng.uniform(0, LEN)
        m = n_samples(0.12)
        e = band(noise(m), 300, 3500)
        env = np.exp(-np.arange(m) / (0.018 * SR))
        add_at(cr, n_samples(at), norm(e * env, rng.uniform(0.5, 0.9)))
    # gentle hiss/sizzle swells (sap)
    for _ in range(int(LEN / 9)):
        at = rng.uniform(0, LEN)
        d = rng.uniform(1.5, 4)
        m = n_samples(d)
        e = band(noise(m), 4000, 11000) * np.sin(np.linspace(0, np.pi, m)) ** 2
        add_at(cr, n_samples(at), norm(e, 0.05))
    out = out + band(cr, 200, 12000) * 0.55
    return reverb(out, 0.25, 0.12)


# ---------------- rain on the roof ----------------
def rain():
    n = n_samples(LEN)
    swell = slow(n, 0.05, 0.18)
    wash = band(noise(n), 400, 9000, slope=-2.5) * swell
    low = band(noise(n), 60, 350) * 0.6 * swell
    out = norm(wash + low, 0.3)
    drops = np.zeros(n)
    # fine patter: many tiny ticks
    k = int(LEN * 900)
    pos = rng.integers(0, n, k)
    amp = rng.lognormal(-2.2, 0.5, k)
    drops[pos] += amp * rng.choice([-1, 1], k)
    drops = band(drops, 1500, 9000) * swell
    out += norm(drops, 0.25)
    # closer drops on the roof and the window: tiny damped taps
    taps = np.zeros(n)
    for _ in range(int(LEN * 7)):
        at = rng.uniform(0, LEN)
        f = rng.uniform(1400, 4200)
        d = rng.uniform(0.004, 0.012)
        m = n_samples(d * 7)
        tt = np.arange(m) / SR
        s = np.sin(2 * np.pi * f * tt) * np.exp(-tt / d)
        add_at(taps, n_samples(at), s * rng.lognormal(-1.4, 0.5))
    out += taps * 0.35
    # a gutter dripping into a puddle, slow and irregular
    tt0 = 0.0
    while tt0 < LEN:
        tt0 += rng.uniform(1.1, 2.6)
        m = n_samples(0.09)
        tt = np.arange(m) / SR
        f0 = rng.uniform(700, 1100)
        f = f0 * (1 + 0.9 * tt / 0.09)  # rising "plink"
        ph = 2 * np.pi * np.cumsum(f) / SR
        s = np.sin(ph) * np.exp(-tt / 0.022)
        add_at(out, n_samples(tt0), s * rng.uniform(0.04, 0.08))
    return reverb(out, 0.4, 0.15)


# ---------------- summer night (fireflies) ----------------
def night():
    n = n_samples(LEN)
    breeze = band(noise(n), 80, 900, slope=-4) * slow(n, 0.06, 0.6)
    leaves = norm(band(noise(n), 1500, 6000) * np.maximum(0, slow(n, 0.1, 1.0, 0.0)) ** 2, 0.025)
    out = norm(breeze, 0.07) + leaves
    cr = np.zeros(n)
    crickets = [  # carrier Hz, chirp period s, pulses, level, distance (lowpass)
        (4600, 0.78, 3, 0.16, 9000),
        (4300, 0.93, 4, 0.10, 6000),
        (4850, 0.66, 3, 0.07, 5000),
        (4100, 1.21, 2, 0.05, 4000),
    ]
    for fc, per, pulses, lvl, lp in crickets:
        one = np.zeros(n)
        tt0 = rng.uniform(0, per)
        while tt0 < LEN:
            for p in range(pulses):
                m = n_samples(0.016)
                tt = np.arange(m) / SR
                s = np.sin(2 * np.pi * fc * tt) * np.sin(np.pi * tt / 0.016) ** 2
                add_at(one, n_samples(tt0 + p * 0.032), s)
            tt0 += per * rng.uniform(0.94, 1.06)
        one = band(one, 2500, lp) * slow(n, 0.08, 0.35)
        cr += norm(one, lvl)
    out += cr
    # a tawny owl now and then, far away
    for at in ([11.0, 37.5] if LEN >= 40 else []):
        for k, (d, f0) in enumerate([(0.55, 410), (0.22, 395), (0.6, 400)]):
            m = n_samples(d)
            tt = np.arange(m) / SR
            f = f0 * (1 + 0.03 * np.sin(np.pi * tt / d)) * (1 + 0.006 * np.sin(2 * np.pi * 6 * tt))
            ph = 2 * np.pi * np.cumsum(f) / SR
            s = (np.sin(ph) + 0.15 * np.sin(2 * ph)) * np.sin(np.pi * tt / d) ** 1.5
            add_at(out, n_samples(at + [0, 0.9, 1.25][k]), s * 0.05)
    return reverb(out, 0.9, 0.3)


if __name__ == "__main__":
    od = sys.argv[1] if len(sys.argv) > 1 else "."
    if len(sys.argv) > 2: LEN = float(sys.argv[2])
    if len(sys.argv) > 3: SR = int(sys.argv[3])
    suffix = sys.argv[4] if len(sys.argv) > 4 else ""
    os.makedirs(od, exist_ok=True)
    for name, fn in [("fire", fire), ("rain", rain), ("night", night)]:
        rng = np.random.default_rng(7)
        save(os.path.join(od, name + suffix + ".wav"), fn())
        print("wrote", name)
