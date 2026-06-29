const themeToggle = document.getElementById('theme-toggle');
const navToggle = document.querySelector('.nav-toggle');
const primaryNav = document.getElementById('primary-nav');

if (navToggle && primaryNav) {
  navToggle.addEventListener('click', () => {
    const isOpen = primaryNav.classList.toggle('open');
    navToggle.classList.toggle('open', isOpen);
    navToggle.setAttribute('aria-expanded', String(isOpen));
  });

  primaryNav.querySelectorAll('a').forEach((link) => {
    link.addEventListener('click', () => {
      primaryNav.classList.remove('open');
      navToggle.classList.remove('open');
      navToggle.setAttribute('aria-expanded', 'false');
    });
  });
}

if (themeToggle) {
  const updateThemeLabel = () => {
    themeToggle.textContent = document.body.classList.contains('light') ? 'Dark' : 'Light';
  };

  if (localStorage.getItem('theme') === 'light') {
    document.body.classList.add('light');
  }

  updateThemeLabel();

  themeToggle.addEventListener('click', () => {
    document.body.classList.toggle('light');
    localStorage.setItem('theme', document.body.classList.contains('light') ? 'light' : 'dark');
    updateThemeLabel();
  });
}

const revealElements = document.querySelectorAll('.section,.card,.skill-card,.blog-card,.blog-post');

if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
  revealElements.forEach((element) => {
    element.style.opacity = 1;
    element.style.transform = 'none';
  });
} else {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.style.opacity = 1;
        entry.target.style.transform = 'translateY(0)';
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12 });

  revealElements.forEach((element) => {
    element.style.opacity = 0.01;
    element.style.transform = 'translateY(10px)';
    observer.observe(element);
  });
}
