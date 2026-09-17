// Animated flow: a clip hops Mac → Samsung and back. Pure SVG + CSS, no JS.
export default function HeroArt() {
  return (
    <div className="hero-art" aria-hidden="true">
      <svg viewBox="0 0 640 330" className="flow">
        <defs>
          <linearGradient id="g" x1="0" x2="1">
            <stop offset="0" stopColor="#FF6A3D" />
            <stop offset="1" stopColor="#FF9A6B" />
          </linearGradient>
          <filter id="glow">
            <feGaussianBlur stdDeviation="6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        {/* two wires: over the top (Mac → phone) and under (phone → Mac) */}
        <path d="M 250 150 C 330 60, 420 60, 500 130" className="wire" />
        <path d="M 500 190 C 420 280, 330 280, 250 190" className="wire" />

        <g className="device mac">
          <rect x="40" y="95" width="210" height="135" rx="14" />
          <rect x="55" y="110" width="180" height="95" rx="6" className="screen" />
          <rect x="105" y="232" width="80" height="8" rx="3" />
          <text x="145" y="262" className="label">Mac</text>
          <g className="ui">
            <rect x="66" y="123" width="60" height="6" rx="3" />
            <rect x="66" y="137" width="120" height="6" rx="3" />
            <rect x="66" y="151" width="85" height="6" rx="3" />
            <rect x="66" y="165" width="100" height="6" rx="3" />
          </g>
        </g>
        <g className="device phone">
          <rect x="500" y="65" width="95" height="190" rx="20" />
          <rect x="510" y="80" width="75" height="160" rx="11" className="screen" />
          <text x="547" y="285" className="label">Samsung</text>
          <g className="ui">
            <rect x="521" y="96" width="40" height="6" rx="3" />
            <rect x="521" y="110" width="54" height="6" rx="3" />
            <rect x="521" y="124" width="30" height="6" rx="3" />
            <rect x="521" y="138" width="48" height="6" rx="3" />
          </g>
        </g>

        <path id="loop" d="M 250 150 C 330 60, 420 60, 500 130 L 500 190 C 420 280, 330 280, 250 190 Z" fill="none" stroke="none" />
        <g className="clip" filter="url(#glow)">
          <rect x="-22" y="-14" width="44" height="28" rx="8" fill="url(#g)" />
          <rect x="-12" y="-5" width="24" height="3" rx="1.5" fill="#fff" opacity=".9" />
          <rect x="-12" y="2" width="16" height="3" rx="1.5" fill="#fff" opacity=".7" />
          <animateMotion dur="6s" repeatCount="indefinite" rotate="0" keyPoints="0;0.42;0.5;0.92;1" keyTimes="0;0.4;0.5;0.9;1" calcMode="linear">
            <mpath href="#loop" />
          </animateMotion>
        </g>
      </svg>
      <div className="hero-caption">
        <span className="dot" /> live: copy on one, it&apos;s on the other in under a second
      </div>
    </div>
  );
}
