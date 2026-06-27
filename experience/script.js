const themeToggle = document.getElementById('theme-toggle');

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
