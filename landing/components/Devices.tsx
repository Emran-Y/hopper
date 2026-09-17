/* Device frames: a MacBook-style laptop and a Galaxy-style phone. Pass a screenshot src;
   the laptop falls back to a stylised render of Hopper's Home tab until a real capture exists. */

export function Laptop({ src, alt }: { src?: string; alt: string }) {
  return (
    <div className="laptop">
      <div className="lid">
        <div className="cam" />
        <div className="screen">
          {src ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={src} alt={alt} />
          ) : (
            <div className="macui" aria-label={alt}>
              <div className="side">
                <div className="b"><i /> Hopper</div>
                <div className="it on">Home</div><div className="it">History</div><div className="it">Devices</div><div className="it">Settings</div>
                <div className="st">● 1 device connected</div>
              </div>
              <div className="main">
                <div className="title">Hopper</div>
                <div className="card hi"><div className="h">● Syncing automatically</div><div className="t">Everything you copy here goes to Galaxy S26, and whatever it copies lands on your clipboard.</div></div>
                <div className="card"><div className="h w">Last received · Galaxy S26 · just now</div><div className="t">https://example.com/design-review</div><span className="pill">encrypted</span></div>
                <div className="card"><div className="h w">Last sent · 2 min ago</div><div className="t">Screenshot 2026-09-17 · 412 KB</div><span className="pill">Galaxy S26 ✓</span></div>
              </div>
            </div>
          )}
        </div>
      </div>
      <div className="base" />
    </div>
  );
}

export function Phone({ src, alt }: { src: string; alt: string }) {
  return (
    <div className="phone">
      <div className="hole" />
      <div className="screen">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={src} alt={alt} />
      </div>
    </div>
  );
}
