/* ── DEN Site Scripts ── */

(function () {
  'use strict';

  /* ── Dynamic version loader ── */
  // Fetches /update.json and updates all .app-version elements.
  // If the fetch fails, the fallback text already in the HTML is kept.
  (function loadAppVersion() {
    fetch('/update.json')
      .then(function (res) {
        if (!res.ok) throw new Error('fetch failed');
        return res.json();
      })
      .then(function (data) {
        var version = (data && data.latest_version) ? data.latest_version : null;
        if (!version) return;
        document.querySelectorAll('.app-version').forEach(function (el) {
          el.textContent = version;
        });
      })
      .catch(function () {
        // Silently fail — fallback text in HTML remains visible
      });
  })();

  /* ── Navbar scroll state ── */
  const navbar = document.querySelector('.navbar');
  if (navbar) {
    window.addEventListener('scroll', function () {
      if (window.scrollY > 20) {
        navbar.classList.add('scrolled');
      } else {
        navbar.classList.remove('scrolled');
      }
    }, { passive: true });
  }

  /* ── Mobile menu toggle ── */
  const hamburger = document.querySelector('.nav-hamburger');
  const navLinks = document.querySelector('.nav-links');
  if (hamburger && navLinks) {
    hamburger.addEventListener('click', function () {
      hamburger.classList.toggle('active');
      navLinks.classList.toggle('active');
      document.body.classList.toggle('no-scroll');
    });
  }

  /* ── Reveal animations on scroll ── */
  const revealElements = document.querySelectorAll('.reveal');
  if (revealElements.length > 0) {
    const revealOnScroll = function () {
      const windowHeight = window.innerHeight;
      revealElements.forEach(function (el) {
        const revealTop = el.getBoundingClientRect().top;
        const revealPoint = 120;
        if (revealTop < windowHeight - revealPoint) {
          el.classList.add('active');
        }
      });
    };
    window.addEventListener('scroll', revealOnScroll, { passive: true });
    // Initial check
    revealOnScroll();
  }

  /* ── Smooth anchor scroll ── */
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
      const href = this.getAttribute('href');
      if (href === '#') return;
      e.preventDefault();
      const target = document.querySelector(href);
      if (target) {
        target.scrollIntoView({ behavior: 'smooth' });
        // Close mobile menu if open
        if (navLinks && navLinks.classList.contains('active')) {
          hamburger.classList.remove('active');
          navLinks.classList.remove('active');
          document.body.classList.remove('no-scroll');
        }
      }
    });
  });

  /* ── Fade navbar on scroll down, show on up ── */
  let lastScrollTop = 0;
  if (navbar) {
    window.addEventListener('scroll', function () {
      let st = window.pageYOffset || document.documentElement.scrollTop;
      if (st > lastScrollTop && st > 100) {
        // Scrolling down
        navbar.style.transform = 'translateY(-100%)';
      } else {
        // Scrolling up
        navbar.style.transform = 'translateY(0)';
      }
      lastScrollTop = st <= 0 ? 0 : st;
    }, { passive: true });
  }

})();
