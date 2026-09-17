"use client";
import { useEffect, useState } from "react";

type Entry = { file: string; platform: string; label: string; note: string; bytes: number; sha256: string };
type Manifest = { version: string; built: string; files: Entry[] };

const fmt = (b: number) => (b > 1048576 ? (b / 1048576).toFixed(1) + " MB" : Math.round(b / 1024) + " KB");

export default function Downloads() {
  const [m, setM] = useState<Manifest | null>(null);
  const [failed, setFailed] = useState(false);
  const [ua, setUa] = useState("");

  useEffect(() => {
    setUa(navigator.userAgent);
    fetch("/downloads/manifest.json", { cache: "no-cache" })
      .then((r) => r.json())
      .then(setM)
      .catch(() => setFailed(true));
  }, []);

  if (failed)
    return (
      <p className="muted">
        Downloads are temporarily unavailable. Get them from <a href="https://github.com/Emran-Y/hopper/releases">GitHub Releases</a> or email <a href="mailto:emranyonas602@gmail.com">emranyonas602@gmail.com</a>.
      </p>
    );
  if (!m) return <p className="muted">Loading…</p>;

  const isMac = /Macintosh/.test(ua), isAndroid = /Android/.test(ua);
  return (
    <>
      <p className="sub">
        Version {m.version} · built {m.built} · every file below has its SHA‑256 next to it.
      </p>
      <div className="dl-grid">
        {m.files.map((f) => {
          const primary =
            (isMac && f.platform === "macOS") || ((isAndroid || !isMac) && f.file.includes("arm64"));
          return (
            <div key={f.file} className={"dl" + (primary ? " primary" : "")}>
              <div className="plat">{f.platform}</div>
              <h3>{f.label}</h3>
              <div className="meta">
                {f.note} · {fmt(f.bytes)}
              </div>
              <div className="sha" title="SHA-256">{f.sha256}</div>
              <a className={"btn" + (primary ? "" : " btn-ghost")} href={`/downloads/${f.file}`} download>
                Download
              </a>
            </div>
          );
        })}
      </div>
    </>
  );
}
