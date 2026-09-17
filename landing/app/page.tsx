import Image from "next/image";
import Downloads from "@/components/Downloads";
import HeroArt from "@/components/HeroArt";

const GITHUB = "https://github.com/Emran-Y/hopper";


export default function Home() {
  return (
    <>
      <header className="nav">
        <a className="brand" href="#top">
          <Image src="/assets/icon.png" alt="" width={28} height={28} />
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
          <div className="hero-text">
            <p className="eyebrow">Free · open source · Mac + Samsung</p>
            <h1>
              Copy here.
              <br />
              <em>Paste there.</em>
            </h1>
            <p className="lead">
              One clipboard across your Mac and your Samsung. Copy on one, paste on the other.
              Nothing to tap, nothing in the cloud, no account. Just your devices talking over your own Wi‑Fi,
              end‑to‑end encrypted.
            </p>
            <div className="cta">
              <a className="btn" href="#download">Download for Mac</a>
              <a className="btn btn-ghost" href="#download">Download for Android</a>
            </div>
            <p className="fine">Text, links, images and files · Under a second on the same Wi‑Fi · Works with the internet unplugged</p>
          </div>
          <HeroArt />
        </section>

        {/* ------------------------------------------------------------ how */}
        <section id="how" className="section">
          <h2>How it works</h2>
          <p className="sub">Three steps, once. After that you never open the app unless you want the history.</p>
          <div className="steps">
            <div className="step">
              <span className="num">1</span>
              <h3>Install on each device</h3>
              <p>The Mac app and the Android app below. Same Wi‑Fi, a phone hotspot counts too.</p>
            </div>
            <div className="step">
              <span className="num">2</span>
              <h3>Pair once with a QR code</h3>
              <p>Mac shows a code, phone scans it. Keys are exchanged in the room, never online. Four emoji on both screens confirm nobody got in between.</p>
            </div>
            <div className="step">
              <span className="num">3</span>
              <h3>Copy anywhere, paste anywhere</h3>
              <p>Copy on the Mac, long‑press → Paste on the Samsung. Copy on the Samsung, ⌘V on the Mac. Screenshots, links, files too.</p>
            </div>
          </div>

          <div className="timeline" aria-label="What happens when you copy">
            <div className="t-item"><span className="t-time">0.0 s</span><span className="t-text">You copy a link on the Samsung</span></div>
            <div className="t-item"><span className="t-time">0.1 s</span><span className="t-text">Hopper notices, encrypts it for each paired device</span></div>
            <div className="t-item"><span className="t-time">0.4 s</span><span className="t-text">It travels over your Wi‑Fi. Not through any server.</span></div>
            <div className="t-item"><span className="t-time">0.8 s</span><span className="t-text">It&apos;s on the Mac clipboard. ⌘V.</span></div>
          </div>
        </section>

        {/* ------------------------------------------------------------ screenshots */}
        <section className="section shots">
          <div className="shot-text">
            <h2>Quiet by design</h2>
            <p className="sub">
              The app is for pairing, history and rules. Day to day, you don&apos;t see it: on the Mac it sits in the menu bar, on Android it&apos;s a small &quot;syncing&quot; notification.
            </p>
            <ul className="checks">
              <li>History of everything that passed through, searchable, pin what you reuse</li>
              <li>Per device: two‑way, one way only, or manual · text / links / images / files toggles · size caps</li>
              <li>Sensitive‑content guard: passwords, one‑time codes and card numbers are held back and you&apos;re asked first</li>
              <li>Light and dark, follows your system or your choice</li>
            </ul>
          </div>
          <div className="shot-imgs">
            <Image src="/assets/phone-dark.png" alt="Hopper on Android, dark theme: status card saying Syncing automatically, last received and last sent clips, paired devices" width={259} height={560} />
            <Image src="/assets/phone-light.png" alt="Hopper on Android, light theme" width={259} height={560} />
          </div>
        </section>

        {/* ------------------------------------------------------------ where */}
        <section id="where" className="section">
          <h2>What works where</h2>
          <p className="sub">Honest version. Phones deliberately block apps from reading the clipboard in the background; here&apos;s what Hopper does about it on each platform.</p>
          <div className="table-wrap">
            <table className="matrix">
              <thead>
                <tr><th></th><th>Mac</th><th>Samsung / Android</th></tr>
              </thead>
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
          <p className="note">
            Why the one‑time USB step on Android: since Android 10, only the app you&apos;re looking at may read the clipboard. Hopper uses the same workaround the well‑known KDE Connect app uses: one permission that only the phone&apos;s owner can grant over a USB cable. After that, Android tells Hopper the moment you copy, and Hopper grabs it through an invisible one‑frame window. You&apos;ll see Android&apos;s own &quot;Hopper pasted from clipboard&quot; toast each time; that&apos;s the OS being transparent, not Hopper.
          </p>
        </section>

        {/* ------------------------------------------------------------ download */}
        <section id="download" className="section">
          <h2>Download</h2>
          <Downloads />
          <div className="dl-notes">
            <p><strong>Mac:</strong> unzip, drag Hopper to Applications and open it. macOS will say it <em>&quot;could not verify Hopper is free of malware&quot;</em>; that&apos;s because the app isn&apos;t notarised with Apple yet. Click <b>Done</b> (not Move to Trash), then <b>System Settings → Privacy &amp; Security</b>, scroll down and click <b>Open Anyway</b>, confirm with your password. Open Hopper again; from then on it just opens. Allow <em>Local Network</em> when asked; that&apos;s how it finds your phone.</p>
            <p><strong>Android:</strong> open the APK on the phone, allow &quot;install from unknown sources&quot; for the app you opened it with (Chrome, Files…), tap Install. Not sure which one? Take <em>64‑bit ARM</em>; it&apos;s every phone made since about 2017.</p>
          </div>
        </section>

        {/* ------------------------------------------------------------ setup */}
        <section id="setup" className="section">
          <h2>Setup, start to finish</h2>
          <div className="guide">
            <details open>
              <summary>Mac + Samsung (5 minutes)</summary>
              <ol>
                <li>Install both apps (above). Put both devices on the same Wi‑Fi.</li>
                <li>
                  <b>Mac, first launch:</b> macOS says <em>&quot;Hopper&quot; Not Opened — Apple could not verify it is free of malware</em>. That&apos;s the standard warning for any app that isn&apos;t from the App Store; Hopper isn&apos;t notarised with Apple yet. Click <b>Done</b> (not Move to Trash), open <b>System Settings → Privacy &amp; Security</b>, scroll down to <em>&quot;Hopper&quot; was blocked</em> and click <b>Open Anyway</b>, confirm with your password, then open Hopper again. Once. Allow <b>Local Network</b> when it asks.
                </li>
                <li>Mac: open Hopper → <b>Devices → Pair device</b>. It shows a QR code.</li>
                <li>Phone: open Hopper → <b>Devices → Pair device</b> → scan the QR. Check the four emoji match on both screens → Done. Clips from the Mac now arrive on the phone automatically.</li>
                <li>
                  To make the phone <em>send</em> automatically too, the one‑time USB step:
                  <ol type="a">
                    <li>Phone: <b>Settings → About phone → Software information</b> → tap <b>Build number</b> 7 times. Then <b>Settings → Developer options → USB debugging</b> → on.</li>
                    <li>Plug the phone into the Mac. Tap <b>Allow</b> on the phone.</li>
                    <li>On the Mac, in Terminal: <code>brew install --cask android-platform-tools</code> once, then <code>bash android-setup.sh</code> (the script from the download list). It grants two permissions and restarts Hopper.</li>
                    <li>Open Hopper on the phone. Android asks <em>&quot;Allow Hopper to access all device logs?&quot;</em> → <b>Allow one‑time access</b>. The Home card turns to &quot;Syncing automatically&quot;.</li>
                  </ol>
                </li>
                <li>After every phone restart: open Hopper once and tap Allow again. That&apos;s Android&apos;s rule, once per boot.</li>
              </ol>
            </details>
            <details>
              <summary>Good to know</summary>
              <ul>
                <li>Same content copied twice within a few seconds is sent once. Copy something else, or wait a moment.</li>
                <li>Something that looks like a password or code is held back; tap <b>Send once</b> on the notification (phone) or the sheet (Mac), or turn the guard off in Settings.</li>
                <li>Samsung&apos;s My Files &quot;Copy&quot; uses a private clipboard apps can&apos;t see. To send a file from the phone use <b>Share → Hopper</b>.</li>
                <li>Guest / office Wi‑Fi often blocks device‑to‑device traffic. A phone hotspot with both devices on it always works.</li>
              </ul>
            </details>
          </div>
        </section>

        {/* ------------------------------------------------------------ privacy */}
        <section className="section privacy">
          <h2>Nothing in between</h2>
          <div className="cols">
            <div><h3>No server</h3><p>There is no Hopper server. Nothing is uploaded, nothing is stored anywhere except on your own devices. Unplug the internet; it still works.</p></div>
            <div><h3>Encrypted end to end</h3><p>Every device has its own key. Pairing swaps keys via the QR code, in the room. Each session gets fresh keys (X25519) and every clip is sealed with XChaCha20‑Poly1305. On a shared Wi‑Fi, others see only noise.</p></div>
            <div><h3>You can read the code</h3><p>Hopper is open source (MIT) at <a href={GITHUB}>github.com/Emran-Y/hopper</a>. The protocol, the encryption and the Android trick are all there to inspect, and every download on this page comes with its checksum.</p></div>
          </div>
        </section>

        {/* ------------------------------------------------------------ next */}
        <section id="next" className="section">
          <h2>What&apos;s next</h2>
          <p className="sub">Where this is going, in rough order.</p>
          <div className="roadmap">
            <div className="rm"><span className="tag">next</span><h3>iPhone</h3><p>The iPhone app exists and works with the Mac; it ships once the App Store side is sorted. Until then, Apple&apos;s own Universal Clipboard covers iPhone ↔ Mac, and Hopper on the Mac relays to the Samsung.</p></div>
            <div className="rm"><span className="tag">next</span><h3>Play Store &amp; notarised Mac app</h3><p>Install from the store, no &quot;unknown sources&quot;, no right‑click → Open.</p></div>
            <div className="rm"><span className="tag">soon</span><h3>Windows &amp; Linux</h3><p>Same code, same protocol; the desktop app already runs on both. Builds and installers are the missing piece.</p></div>
            <div className="rm"><span className="tag">soon</span><h3>Big files</h3><p>Chunked, resumable transfers with an accept step, so a 500 MB video doesn&apos;t surprise anyone.</p></div>
            <div className="rm"><span className="tag">later</span><h3>Bluetooth fallback</h3><p>Text and links sync even with no Wi‑Fi at all, e.g. on a train.</p></div>
            <div className="rm"><span className="tag">later</span><h3>Offline queue</h3><p>Copied while the other device was away? It arrives when it&apos;s back.</p></div>
            <div className="rm"><span className="tag">later</span><h3>Hopper keyboard for Android</h3><p>An optional keyboard that makes phone → PC automatic without the USB step.</p></div>
            <div className="rm"><span className="tag">later</span><h3>Encrypted history</h3><p>History encrypted at rest with the OS keystore, plus retention by days.</p></div>
          </div>
        </section>

        {/* ------------------------------------------------------------ faq */}
        <section className="section faq">
          <h2>Questions</h2>
          <details><summary>Is it safe to install something that isn&apos;t from the App Store or Play Store?</summary><p>The warnings you see on the Mac (&quot;could not verify&quot;) and on Android (&quot;unknown sources&quot;) appear for <em>every</em> app that isn&apos;t distributed through Apple&apos;s or Google&apos;s store, regardless of what it does. Hopper isn&apos;t in the stores yet. What you can do instead of trusting a store: read the code at <a href={GITHUB}>github.com/Emran-Y/hopper</a>, check the SHA‑256 of the file you downloaded against the one shown above, and note that the app has no server to talk to. Store listings are on the roadmap.</p></details>
          <details><summary>Is this like Apple&apos;s Universal Clipboard or Samsung&apos;s Link to Windows?</summary><p>Same idea, but across brands (a Mac and a Samsung), and without routing your clipboard through anyone&apos;s servers.</p></details>
          <details><summary>Does it need the internet?</summary><p>No. It needs the devices to reach each other on a local network: home Wi‑Fi, office Wi‑Fi, or a phone hotspot. The internet can be down.</p></details>
          <details><summary>Why does the Android setup need a USB cable?</summary><p>Because the permission Hopper needs to notice your copies can only be granted by you, through Android&apos;s developer tools. No app can ask for it, and Hopper can&apos;t get it by itself. It&apos;s the same for KDE Connect and every app in this category.</p></details>
          <details><summary>How big can a clip be?</summary><p>By default images up to 25 MB and files up to 50 MB per device, adjustable in each device&apos;s rules up to 100 MB. Larger transfers are on the roadmap.</p></details>
          <details><summary>What&apos;s &quot;Hopper pasted from clipboard&quot; on my Samsung?</summary><p>Android 12+ shows that toast whenever any app reads the clipboard. It&apos;s Android being transparent about the capture; it can&apos;t be turned off by an app.</p></details>
          <details><summary>Can I share it with friends?</summary><p>Yes, send them this page. Each pair of their devices pairs with its own keys; your devices never see theirs.</p></details>
        </section>
      </main>

      <footer>
        <div>
          <Image src="/assets/icon.png" alt="" width={22} height={22} /> Hopper · open source (MIT) ·{" "}
          <a href={GITHUB}>github.com/Emran-Y/hopper</a> · built by Emran Yonas
        </div>
        <div className="muted">
          Want to reach out or collaborate on Hopper? <a href="mailto:emranyonas602@gmail.com">emranyonas602@gmail.com</a>
        </div>
      </footer>
    </>
  );
}
