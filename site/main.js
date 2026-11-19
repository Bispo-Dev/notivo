// Motion (motion.dev) brings the page to life; everything still works without it.
const MOTION = 'https://cdn.jsdelivr.net/npm/motion@12/+esm';
const ease = [0.22, 1, 0.36, 1];
const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

// Phones: a download button docks at the bottom once the hero button scrolls away.
const dock = document.querySelector('[data-dock]');
const heroButton = document.getElementById('download');
new IntersectionObserver(([entry]) => {
  dock.classList.toggle('is-visible', !entry.isIntersecting);
}).observe(heroButton);

async function start() {
  if (reduce) return;
  let motion;
  try {
    motion = await import(MOTION);
  } catch {
    return; // Offline or blocked CDN: the page stays static.
  }
  const { animate, inView, stagger, hover, press } = motion;

  // Hero copy rises in, one line after the other.
  animate(
    '[data-hero]',
    { opacity: [0, 1], y: [24, 0] },
    { duration: 0.7, delay: stagger(0.08), ease },
  );

  // The app icon tilts in 3D toward the pointer or finger and springs back
  // when it leaves; nothing moves on its own.
  const box = document.querySelector('[data-device]');
  const icon = box.querySelector('img');
  animate(icon, { opacity: [0, 1] }, { duration: 0.6, delay: 0.2 });
  const follow = { type: 'spring', stiffness: 300, damping: 20 };
  box.addEventListener('pointermove', (event) => {
    const r = box.getBoundingClientRect();
    const x = (event.clientX - r.left) / r.width - 0.5;
    const y = (event.clientY - r.top) / r.height - 0.5;
    animate(icon, { rotateY: x * 30, rotateX: -y * 30 }, follow);
  });
  const settle = () =>
    animate(icon, { rotateY: 0, rotateX: 0 }, { type: 'spring', stiffness: 200, damping: 14 });
  box.addEventListener('pointerleave', settle);
  box.addEventListener('pointerup', settle);
  box.addEventListener('pointercancel', settle);

  // Sections fade up as they enter the screen.
  document.querySelectorAll('[data-reveal]').forEach((el) => {
    el.style.opacity = '0';
  });
  inView(
    '[data-reveal]',
    (el) => {
      animate(el, { opacity: [0, 1], y: [28, 0] }, { duration: 0.6, ease });
    },
    { amount: 0.25 },
  );

  // Buttons answer touch with a small spring, like the app.
  document.querySelectorAll('.button').forEach((button) => {
    hover(button, () => {
      animate(button, { scale: 1.03 }, { type: 'spring', stiffness: 400, damping: 20 });
      return () => animate(button, { scale: 1 }, { type: 'spring', stiffness: 400, damping: 20 });
    });
    press(button, () => {
      animate(button, { scale: 0.96 }, { type: 'spring', stiffness: 500, damping: 25 });
      return () => animate(button, { scale: 1 }, { type: 'spring', stiffness: 500, damping: 25 });
    });
  });
}

start();
