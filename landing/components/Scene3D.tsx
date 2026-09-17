"use client";
import { useEffect, useRef } from "react";

/**
 * WebGL backdrop for the hero stage: a particle stream that flows along a 3D curve
 * between the laptop (left) and the phone (right), a glowing "clip" sprite that rides
 * the stream back and forth, a slow drifting star field, and camera parallax that
 * follows the pointer. Pauses off-screen and under prefers-reduced-motion.
 */
export default function Scene3D() {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const host = ref.current;
    if (!host) return;
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    let disposed = false;
    let cleanup = () => {};

    import("three").then((THREE) => {
      if (disposed) return;
      const W = () => host.clientWidth, H = () => host.clientHeight;

      const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: "high-performance" });
      renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
      renderer.setSize(W(), H());
      renderer.setClearColor(0x000000, 0);
      host.appendChild(renderer.domElement);

      const scene = new THREE.Scene();
      const camera = new THREE.PerspectiveCamera(38, W() / H(), 0.1, 100);
      camera.position.set(0, 0.2, 9);

      // ---- soft round particle texture (shared)
      const dotTex = (() => {
        const c = document.createElement("canvas"); c.width = c.height = 64;
        const g = c.getContext("2d")!;
        const grd = g.createRadialGradient(32, 32, 0, 32, 32, 32);
        grd.addColorStop(0, "rgba(255,255,255,1)"); grd.addColorStop(0.35, "rgba(255,255,255,.55)"); grd.addColorStop(1, "rgba(255,255,255,0)");
        g.fillStyle = grd; g.fillRect(0, 0, 64, 64);
        const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
      })();

      // ---- the flow curve: laptop (left, low) → phone (right, slightly higher), arcing towards the viewer
      let curve = new THREE.CatmullRomCurve3([new THREE.Vector3(), new THREE.Vector3()]);
      const rebuildCurve = () => {
        const aspect = W() / Math.max(H(), 1);
        if (aspect >= 1) {
          const span = 3.2 * Math.min(1.4, Math.max(0.8, aspect / 2.2));
          curve = new THREE.CatmullRomCurve3([
            new THREE.Vector3(-span, -0.4, -0.6), new THREE.Vector3(-span * 0.45, 1.1, 1.2),
            new THREE.Vector3(span * 0.4, 1.3, 1.0), new THREE.Vector3(span, 0.2, -0.4),
          ]);
          camera.position.z = 9;
        } else {
          // stacked layout: laptop above, phone below → the stream flows top to bottom
          const h = 3.4 / Math.max(0.55, aspect);
          curve = new THREE.CatmullRomCurve3([
            new THREE.Vector3(-0.4, h * 0.45, -0.4), new THREE.Vector3(1.4, h * 0.15, 1.0),
            new THREE.Vector3(-1.2, -h * 0.15, 1.0), new THREE.Vector3(0.3, -h * 0.45, -0.4),
          ]);
          camera.position.z = 9 + (h - 3.4) * 1.1;
        }
      };
      rebuildCurve();

      // ---- stream particles along the curve
      const N = 700;
      const sPos = new Float32Array(N * 3), sCol = new Float32Array(N * 3), sSize = new Float32Array(N);
      const sT = new Float32Array(N), sV = new Float32Array(N), sOff = new Float32Array(N * 3);
      const cA = new THREE.Color("#ff8a5c"), cB = new THREE.Color("#57d7ff"), tmp = new THREE.Color();
      for (let i = 0; i < N; i++) {
        sT[i] = Math.random(); sV[i] = 0.05 + Math.random() * 0.09;
        sOff[i * 3] = (Math.random() - 0.5) * 0.35; sOff[i * 3 + 1] = (Math.random() - 0.5) * 0.35; sOff[i * 3 + 2] = (Math.random() - 0.5) * 0.35;
        sSize[i] = 0.035 + Math.random() * 0.08;
      }
      const sGeo = new THREE.BufferGeometry();
      sGeo.setAttribute("position", new THREE.BufferAttribute(sPos, 3));
      sGeo.setAttribute("color", new THREE.BufferAttribute(sCol, 3));
      sGeo.setAttribute("size", new THREE.BufferAttribute(sSize, 1));
      const sMat = new THREE.ShaderMaterial({
        uniforms: { map: { value: dotTex }, uScale: { value: Math.min(W(), H()) } },
        vertexShader: `attribute float size; varying vec3 vC; uniform float uScale;
          void main(){ vC = color; vec4 mv = modelViewMatrix * vec4(position,1.0); gl_PointSize = size * uScale * 0.18 / -mv.z; gl_Position = projectionMatrix * mv; }`,
        fragmentShader: `uniform sampler2D map; varying vec3 vC; void main(){ vec4 t = texture2D(map, gl_PointCoord); gl_FragColor = vec4(vC, 1.0) * t; }`,
        vertexColors: true, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
      });
      const stream = new THREE.Points(sGeo, sMat); scene.add(stream);

      // ---- drifting star field
      const M = 500;
      const fPos = new Float32Array(M * 3), fCol = new Float32Array(M * 3), fSize = new Float32Array(M);
      for (let i = 0; i < M; i++) {
        fPos[i * 3] = (Math.random() - 0.5) * 16; fPos[i * 3 + 1] = (Math.random() - 0.5) * 9; fPos[i * 3 + 2] = -2 - Math.random() * 8;
        const c = Math.random() < 0.7 ? new THREE.Color("#8ea2c9") : cA; fCol.set([c.r * 0.6, c.g * 0.6, c.b * 0.6], i * 3);
        fSize[i] = 0.02 + Math.random() * 0.05;
      }
      const fGeo = new THREE.BufferGeometry();
      fGeo.setAttribute("position", new THREE.BufferAttribute(fPos, 3));
      fGeo.setAttribute("color", new THREE.BufferAttribute(fCol, 3));
      fGeo.setAttribute("size", new THREE.BufferAttribute(fSize, 1));
      const field = new THREE.Points(fGeo, sMat.clone()); scene.add(field);

      // ---- the clip: a rounded card sprite with a glow behind it
      const cardTex = (() => {
        const c = document.createElement("canvas"); c.width = 256; c.height = 160;
        const g = c.getContext("2d")!;
        const r = 28; g.beginPath(); g.roundRect(8, 8, 240, 144, r);
        const grd = g.createLinearGradient(0, 0, 256, 160); grd.addColorStop(0, "#ff8a5c"); grd.addColorStop(1, "#ff5a2b");
        g.fillStyle = grd; g.shadowColor = "rgba(255,106,61,.9)"; g.shadowBlur = 18; g.fill();
        g.shadowBlur = 0; g.fillStyle = "rgba(255,255,255,.92)";
        g.roundRect(40, 52, 130, 14, 7); g.fill(); g.fillStyle = "rgba(255,255,255,.7)"; g.roundRect(40, 84, 90, 14, 7); g.fill();
        const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
      })();
      const clip = new THREE.Sprite(new THREE.SpriteMaterial({ map: cardTex, transparent: true, depthWrite: false }));
      clip.scale.set(0.42, 0.26, 1); scene.add(clip);
      const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: dotTex, color: 0xff6a3d, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, opacity: 0.5 }));
      glow.scale.set(1.0, 1.0, 1); scene.add(glow);

      // ---- interaction
      const mouse = new THREE.Vector2(0, 0), target = new THREE.Vector2(0, 0);
      const onMove = (e: PointerEvent) => { const r = host.getBoundingClientRect(); target.set(((e.clientX - r.left) / r.width - 0.5) * 2, -((e.clientY - r.top) / r.height - 0.5) * 2); };
      const onLeave = () => target.set(0, 0);
      window.addEventListener("pointermove", onMove, { passive: true });
      host.addEventListener("pointerleave", onLeave);

      let visible = true;
      const io = new IntersectionObserver((en) => { visible = en[0].isIntersecting; }, { threshold: 0.02 });
      io.observe(host);

      const onResize = () => { renderer.setSize(W(), H()); camera.aspect = W() / H(); camera.updateProjectionMatrix(); sMat.uniforms.uScale.value = Math.min(W(), H()); (field.material as typeof sMat).uniforms.uScale.value = Math.min(W(), H()); rebuildCurve(); };
      window.addEventListener("resize", onResize);

      // ---- animation loop
      const P = new THREE.Vector3();
      let raf = 0, t0 = performance.now();
      const ease = (x: number) => (x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2);
      const frame = (now: number) => {
        raf = requestAnimationFrame(frame);
        if (!visible) return;
        const dt = Math.min(0.05, (now - t0) / 1000); t0 = now;
        const time = now / 1000;

        // stream
        const pos = sGeo.attributes.position.array as Float32Array, col = sGeo.attributes.color.array as Float32Array;
        for (let i = 0; i < N; i++) {
          sT[i] = (sT[i] + sV[i] * dt) % 1;
          curve.getPointAt(sT[i], P);
          const w = Math.sin(time * 1.3 + i) * 0.06;
          pos[i * 3] = P.x + sOff[i * 3] + w; pos[i * 3 + 1] = P.y + sOff[i * 3 + 1] + w; pos[i * 3 + 2] = P.z + sOff[i * 3 + 2];
          tmp.copy(cA).lerp(cB, sT[i]); const b = 0.35 + 0.65 * Math.sin(sT[i] * Math.PI);
          col[i * 3] = tmp.r * b; col[i * 3 + 1] = tmp.g * b; col[i * 3 + 2] = tmp.b * b;
        }
        sGeo.attributes.position.needsUpdate = true; sGeo.attributes.color.needsUpdate = true;

        // clip travels there and back, pausing briefly at each device
        const period = 7, ph = (time % period) / period;
        const seg = ph < 0.5 ? ph / 0.5 : 1 - (ph - 0.5) / 0.5;
        const tt = ease(Math.min(1, Math.max(0, (seg - 0.06) / 0.88)));
        curve.getPointAt(tt, P);
        clip.position.copy(P).add(new THREE.Vector3(0, 0.1, 0.3));
        const pulse = 1 + 0.06 * Math.sin(time * 5);
        clip.scale.set(0.42 * pulse, 0.26 * pulse, 1);
        glow.position.copy(clip.position); glow.scale.setScalar(0.95 + 0.2 * Math.sin(time * 3));

        // field drift + parallax
        field.rotation.y = Math.sin(time * 0.05) * 0.08; field.position.y = Math.sin(time * 0.2) * 0.1;
        mouse.lerp(target, 0.06);
        camera.position.x = mouse.x * 0.7; camera.position.y = 0.2 + mouse.y * 0.45;
        camera.lookAt(0, 0.35, 0);

        renderer.render(scene, camera);
      };
      if (reduced) { // one static frame
        for (let i = 0; i < N; i++) { curve.getPointAt(sT[i], P); sPos.set([P.x + sOff[i * 3], P.y + sOff[i * 3 + 1], P.z + sOff[i * 3 + 2]], i * 3); tmp.copy(cA).lerp(cB, sT[i]); sCol.set([tmp.r, tmp.g, tmp.b], i * 3); }
        sGeo.attributes.position.needsUpdate = true; sGeo.attributes.color.needsUpdate = true;
        curve.getPointAt(0.5, P); clip.position.copy(P); glow.position.copy(P); renderer.render(scene, camera);
      } else {
        raf = requestAnimationFrame(frame);
      }

      cleanup = () => {
        cancelAnimationFrame(raf); io.disconnect();
        window.removeEventListener("pointermove", onMove); window.removeEventListener("resize", onResize); host.removeEventListener("pointerleave", onLeave);
        renderer.dispose(); sGeo.dispose(); fGeo.dispose(); dotTex.dispose(); cardTex.dispose();
        if (renderer.domElement.parentNode === host) host.removeChild(renderer.domElement);
      };
    });

    return () => { disposed = true; cleanup(); };
  }, []);

  return <div ref={ref} className="scene3d" aria-hidden="true" />;
}
