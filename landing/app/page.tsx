import Downloads from "@/components/Downloads";
import Reveal from "@/components/Reveal";
import { Laptop, Phone } from "@/components/Devices";

const GITHUB = "https://github.com/Emran-Y/hopper";

export default function Home() {
  return (
    <>
      <div className="ambient" aria-hidden="true" />
      <Reveal />

      <header className="nav">
        <a className="brand" href="#top">
          <img src="assets/icon.png" alt="" width={28} height={28} />
          <span>Hopper</span>
        </a>
        <nav>
          <a href="#how">How it works</a>
          <a href="#where">What works where</a>
          <a href="#download">Download</a>
          <a href="#setup">Setup</a>
          <a href="#next">What&apos;s next</a>
          <a href={GITHUB} target="_blank" rel="noopener">Source</a>
        </nav>
        <a className="btn btn-sm" href="#download">Get Hopper</a>
      </header>

      <main id="top">
        {/* ------------------------------------------------------------ hero */}
        <section className="hero">
          <span className="eyebrow"><span className="dot" /> Free · open source · Mac + Samsung</span>
          <h1>
            Copy here.<br />
            <span className="grad">Paste there.</span>
          </h1>
          <p className="lead">
            One clipboard across your Mac and your Samsung. Copy on one, paste on the other. Nothing to tap,
            nothing in the cloud, no account. Your devices talking directly over your own Wi‑Fi, end‑to‑end encrypted.
          </p>
          <div className="cta">
            <a className="btn" href="#download">Download for Mac</a>
            <a className="btn btn-ghost" href="#download">Download for Android</a>
          </div>
          <p className="fine">Text · links · images · files · under a second · works with the internet unplugged</p>

          <div className="stage">
            <div className="beam" aria-hidden="true" />
            <div className="stage-grid">
              <div>
                <Laptop src={undefined} alt="Hopper on the Mac: sidebar with Home, History, Devices, Settings; the Home tab shows Syncing automatically, the last received clip and the last sent clip" />
                
              </div>
              <div>
                <Phone src="assets/phone-dark.png" alt="Hopper on a Samsung Galaxy: Syncing automatically, last sent clip, paired devices" />
                
              </div>
            </div>
            <div className="stage-floor" aria-hidden="true" />
          </div>
        </section>

        {/* ------------------------------------------------------------ pillars */}
        <section className="section">
          <div className="grid3">
            <div className="glass reveal">
              <div className="ico">⚡</div>
              <h3>Under a second</h3>
              <p>Copy on the phone, ⌘V on the Mac. It rides your Wi‑Fi at LAN speed, never a server. Unplug the internet and it still works.</p>
            </div>
            <div className="glass reveal">
              <div className="ico">🔒</div>
              <h3>Sealed end to end</h3>
              <p>Keys are swapped in the room through a QR code. Every session gets fresh keys, every clip is encrypted. On a shared Wi‑Fi, others see noise.</p>
            </div>
            <div className="glass reveal">
              <div className="ico">🫥</div>
              <h3>Invisible after setup</h3>
              <p>A menu‑bar icon on the Mac, a quiet notification on the phone. You only open the app to pair a device or dig through history.</p>
            </div>
          </div>
        </section>

        {/* ------------------------------------------------------------ how */}
        <section id="how" className="section">
          <h2 className="reveal">How it works</h2>
          <p className="sub reveal">Three steps, once. After that you never open the app unless you want the history.</p>
          <div className="grid3">
            <div className="glass reveal"><span className="num">1</span><h3>Install on each device</h3><p>The Mac app and the Android app below. Same Wi‑Fi; a phone hotspot counts too.</p></div>
            <div className="glass reveal"><span className="num">2</span><h3>Pair once with a QR code</h3><p>Mac shows a code, phone scans it. Four emoji on both screens confirm nobody got in between.</p></div>
            <div className="glass reveal"><span className="num">3</span><h3>Copy anywhere, paste anywhere</h3><p>Copy on the Mac, long‑press → Paste on the Samsung. Copy on the Samsung, ⌘V on the Mac. Screenshots, links, files too.</p></div>
          </div>
          <div className="timeline reveal" aria-label="What happens when you copy">
            <div className="t-item"><span className="t-time">0.0 s</span><span className="t-text">You copy a link on the Samsung</span></div>
            <div className="t-item"><span className="t-time">0.1 s</span><span className="t-text">Hopper notices and encrypts it for each paired device</span></div>
            <div className="t-item"><span className="t-time">0.4 s</span><span className="t-text">It crosses your Wi‑Fi. Not a single server in between.</span></div>
            <div className="t-item"><span className="t-time">0.8 s</span><span className="t-text">It&apos;s on the Mac clipboard. ⌘V.</span></div>
          </div>
        </section>

        {/* ------------------------------------------------------------ gallery */}
        <section className="section">
          <h2 className="reveal">Quiet by design</h2>
          <p className="sub reveal">The app is for pairing, history and rules. Day to day you don&apos;t see it.</p>
          <div className="gallery">
            <div className="reveal"><Laptop src={undefined} alt="Hopper on the Mac, Home tab" /></div>
            <div className="reveal"><Phone src="assets/phone-history.png" alt="Hopper on Android: History tab with search and filters" /></div>
            <div className="reveal"><Phone src="assets/phone-light.png" alt="Hopper on Android, light theme" /></div>
          </div>
          <div className="grid3" style={{ marginTop: 28 }}>
            <div className="glass reveal"><h3>History</h3><p>Everything that passed through, searchable. Tap to copy again, pin what you reuse, send any old clip to a specific device.</p></div>
            <div className="glass reveal"><h3>Rules per device</h3><p>Two‑way, one way only, or manual. Toggle text, links, images and files. Size caps per device.</p></div>
            <div className="glass reveal"><h3>Sensitive‑content guard</h3><p>Passwords, one‑time codes and card numbers are held back and you&apos;re asked first.</p></div>
          </div>
        </section>

        {/* ------------------------------------------------------------ where */}
        <section id="where" className="section">
          <h2 className="reveal">What works where</h2>
          <p className="sub reveal">Honest version. Phones deliberately block apps from reading the clipboard in the background; here&apos;s what Hopper does about it.</p>
          <div className="table-wrap reveal">
            <table className="matrix">
              <thead><tr><th></th><th>Mac</th><th>Samsung / Android</th></tr></thead>
              <tbody>
                <tr><th>Receive automatically</th><td className="ok">Yes</td><td className="ok">Yes, always on — even with the app closed or after a reboot</td></tr>
                <tr><th>Send automatically</th><td className="ok">Yes, everything you copy</td><td className="ok">Yes, after a 2‑minute one‑time setup over USB</td></tr>
                <tr><th>Text &amp; links</th><td className="ok">Yes</td><td className="ok">Yes</td></tr>
                <tr><th>Images &amp; screenshots</th><td className="ok">Yes</td><td className="ok">Yes, also saved to Gallery</td></tr>
                <tr><th>Files</th><td className="ok">Copy in Finder → sent. Received files land in Downloads/Hopper</td><td className="ok">Received into Downloads/Hopper. Send with Share → Hopper</td></tr>
                <tr><th>Needs</th><td>macOS 12+</td><td>Android 7+ · Samsung, Pixel, anything</td></tr>
              </tbody>
            </table>
          </div>
          <p className="note reveal">
            Why the one‑time USB step on Android: since Android 10, only the app you&apos;re looking at may read the clipboard. Hopper uses the same workaround the well‑known KDE Connect app uses: one permission that only the phone&apos;s owner can grant over a USB cable. After that, Android tells Hopper the moment you copy, and Hopper grabs it through an invisible one‑frame window. You&apos;ll see Android&apos;s own &quot;Hopper pasted from clipboard&quot; toast each time; that&apos;s the OS being transparent, not Hopper.
          </p>
        </section>

        {/* ------------------------------------------------------------ download */}
        <section id="download" className="section">
          <h2 className="reveal">Download</h2>
          <Downloads />
          <div className="dl-notes reveal">
            <p><strong>Mac:</strong> unzip, drag Hopper to Applications and open it. macOS will say it <em>&quot;could not verify Hopper is free of malware&quot;</em> because the app isn&apos;t notarised with Apple yet. Click <b>Done</b>, then <b>System Settings → Privacy &amp; Security</b>, scroll down, <b>Open Anyway</b>. Once. Allow <em>Local Network</em> when asked.</p>
            <p><strong>Android:</strong> open the APK on the phone, allow &quot;install from unknown sources&quot; for the app you opened it with, tap Install. Not sure which one? Take <em>64‑bit ARM</em>; it&apos;s every phone made since about 2017.</p>
          </div>
        </section>

        {/* ------------------------------------------------------------ setup */}
        <section id="setup" className="section guide">
          <h2 className="reveal">Setup, start to finish</h2>
          <details className="glass reveal" open>
            <summary>Mac + Samsung (5 minutes)</summary>
            <ol>
              <li>Install both apps (above). Put both devices on the same Wi‑Fi.</li>
              <li>
                <b>Mac, first launch:</b> macOS says <em>&quot;Hopper&quot; Not Opened — Apple could not verify it is free of malware</em>. That&apos;s the standard warning for any app that isn&apos;t from the App Store; Hopper isn&apos;t notarised with Apple yet. Click <b>Done</b> (not Move to Trash), open <b>System Settings → Privacy &amp; Security</b>, scroll down to <em>&quot;Hopper&quot; was blocked</em> and click <b>Open Anyway</b>, confirm with your password, then open Hopper again. Once. Allow <b>Local Network</b> when it asks.
              </li>
              <li>Mac: <b>Devices → Pair device</b>. It shows a QR code.</li>
              <li>Phone: <b>Devices → Pair device</b> → scan the QR. Check the four emoji match → Done. Clips from the Mac now arrive on the phone automatically.</li>
              <li>
                To make the phone <em>send</em> automatically too, the one‑time USB step:
                <ol type="a">
                  <li>Phone: <b>Settings → About phone → Software information</b> → tap <b>Build number</b> 7 times. Then <b>Settings → Developer options → USB debugging</b> → on.</li>
                  <li>Plug the phone into the Mac. Tap <b>Allow</b> on the phone.</li>
                  <li>On the Mac, in Terminal: <code>brew install --cask android-platform-tools</code> once, then <code>bash android-setup.sh</code> (from the download list). It grants two permissions and restarts Hopper.</li>
                  <li>Open Hopper on the phone. Android asks <em>&quot;Allow Hopper to access all device logs?&quot;</em> → <b>Allow one‑time access</b>. The Home card turns to &quot;Syncing automatically&quot;.</li>
                </ol>
              </li>
              <li>After every phone restart: open Hopper once and tap Allow again. That&apos;s Android&apos;s rule, once per boot.</li>
            </ol>
          </details>
          <details className="glass reveal">
            <summary>Good to know</summary>
            <ul>
              <li>Same content copied twice within a few seconds is sent once. Copy something else, or wait a moment.</li>
              <li>Something that looks like a password or code is held back; tap <b>Send once</b> on the notification (phone) or the sheet (Mac), or turn the guard off in Settings.</li>
              <li>Samsung&apos;s My Files &quot;Copy&quot; uses a private clipboard apps can&apos;t see. To send a file from the phone use <b>Share → Hopper</b>.</li>
              <li>Guest / office Wi‑Fi often blocks device‑to‑device traffic. A phone hotspot with both devices on it always works.</li>
            </ul>
          </details>
        </section>

        {/* ------------------------------------------------------------ privacy */}
        <section className="section">
          <h2 className="reveal">Nothing in between</h2>
          <div className="grid3">
            <div className="glass reveal"><h3>No server</h3><p>There is no Hopper server. Nothing is uploaded, nothing is stored anywhere except on your own devices.</p></div>
            <div className="glass reveal"><h3>Encrypted end to end</h3><p>Ed25519 identities, X25519 session keys, XChaCha20‑Poly1305 on every clip. Unknown devices are silently ignored.</p></div>
            <div className="glass reveal"><h3>You can read the code</h3><p>Open source (MIT) at <a href={GITHUB}>github.com/Emran-Y/hopper</a>. The protocol, the encryption and the Android trick are all there, and every download has its checksum.</p></div>
          </div>
        </section>

        {/* ------------------------------------------------------------ next */}
        <section id="next" className="section">
          <h2 className="reveal">What&apos;s next</h2>
          <p className="sub reveal">Where this is going, in rough order.</p>
          <div className="grid3">
            <div className="glass reveal"><span className="tag hot">next</span><h3>iPhone</h3><p>The iPhone app exists and works with the Mac; it ships once the App Store side is sorted. Until then Apple&apos;s Universal Clipboard covers iPhone ↔ Mac and Hopper relays to the Samsung.</p></div>
            <div className="glass reveal"><span className="tag hot">next</span><h3>Play Store &amp; notarised Mac app</h3><p>Install from the store: no &quot;unknown sources&quot;, no Open Anyway.</p></div>
            <div className="glass reveal"><span className="tag">soon</span><h3>Windows &amp; Linux</h3><p>Same code, same protocol; the desktop app already runs on both. Builds and installers are the missing piece.</p></div>
            <div className="glass reveal"><span className="tag">soon</span><h3>Big files</h3><p>Chunked, resumable transfers with an accept step, so a 500 MB video doesn&apos;t surprise anyone.</p></div>
            <div className="glass reveal"><span className="tag">later</span><h3>Bluetooth fallback</h3><p>Text and links sync with no Wi‑Fi at all, e.g. on a train.</p></div>
            <div className="glass reveal"><span className="tag">later</span><h3>Offline queue</h3><p>Copied while the other device was away? It arrives when it&apos;s back.</p></div>
          </div>
        </section>

        {/* ------------------------------------------------------------ faq */}
        <section className="section faq">
          <h2 className="reveal">Questions</h2>
          <details className="glass reveal"><summary>Is it safe to install something that isn&apos;t from the App Store or Play Store?</summary><p>The warnings on the Mac (&quot;could not verify&quot;) and on Android (&quot;unknown sources&quot;) appear for <em>every</em> app that isn&apos;t distributed through Apple&apos;s or Google&apos;s store, regardless of what it does. Hopper isn&apos;t in the stores yet. Instead of trusting a store you can read the code at <a href={GITHUB}>github.com/Emran-Y/hopper</a>, compare the SHA‑256 of your download with the one shown above, and note that the app has no server to talk to.</p></details>
          <details className="glass reveal"><summary>Is this like Apple&apos;s Universal Clipboard or Samsung&apos;s Link to Windows?</summary><p>Same idea, but across brands (a Mac and a Samsung), and without routing your clipboard through anyone&apos;s servers.</p></details>
          <details className="glass reveal"><summary>Does it need the internet?</summary><p>No. It needs the devices to reach each other on a local network: home Wi‑Fi, office Wi‑Fi, or a phone hotspot. The internet can be down.</p></details>
          <details className="glass reveal"><summary>Why does the Android setup need a USB cable?</summary><p>Because the permission Hopper needs to notice your copies can only be granted by you, through Android&apos;s developer tools. No app can ask for it. It&apos;s the same for KDE Connect and every app in this category.</p></details>
          <details className="glass reveal"><summary>How big can a clip be?</summary><p>By default images up to 25 MB and files up to 50 MB per device, adjustable in each device&apos;s rules up to 100 MB. Larger transfers are on the roadmap.</p></details>
          <details className="glass reveal"><summary>Can I share it with friends?</summary><p>Yes, send them this page. Each pair of their devices pairs with its own keys; your devices never see theirs.</p></details>
        </section>
      </main>

      <footer>
        <div>
          <img src="assets/icon.png" alt="" width={22} height={22} /> Hopper · open source (MIT) ·{" "}
          <a href={GITHUB}>github.com/Emran-Y/hopper</a> · built by Emran Yonas
        </div>
        <div>
          Want to reach out or collaborate? <a href="mailto:emranyonas602@gmail.com">emranyonas602@gmail.com</a>
        </div>
      </footer>
    </>
  );
}
