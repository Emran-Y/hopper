"use client";
import { useEffect, useRef } from "react";

/** Perspective tilt that follows the pointer (max a few degrees), springs back on leave. */
export default function Tilt({ children, max = 7, className = "" }: { children: React.ReactNode; max?: number; className?: string }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = ref.current; if (!el) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches || !window.matchMedia("(pointer: fine)").matches) return;
    let raf = 0, rx = 0, ry = 0, tx = 0, ty = 0;
    const tick = () => { rx += (tx - rx) * 0.12; ry += (ty - ry) * 0.12; el.style.transform = `perspective(1400px) rotateX(${rx}deg) rotateY(${ry}deg)`; if (Math.abs(tx - rx) > 0.01 || Math.abs(ty - ry) > 0.01) raf = requestAnimationFrame(tick); };
    const move = (e: PointerEvent) => {
      const r = el.getBoundingClientRect();
      const px = (e.clientX - r.left) / r.width - 0.5, py = (e.clientY - r.top) / r.height - 0.5;
      // the whole viewport drives the tilt a little, the element itself a lot
      const inside = px > -0.6 && px < 0.6 && py > -0.6 && py < 0.6;
      tx = (inside ? -py * max : 0); ty = (inside ? px * max : 0);
      cancelAnimationFrame(raf); raf = requestAnimationFrame(tick);
    };
    window.addEventListener("pointermove", move, { passive: true });
    return () => { window.removeEventListener("pointermove", move); cancelAnimationFrame(raf); };
  }, [max]);
  return <div ref={ref} className={`tilt ${className}`}>{children}</div>;
}
