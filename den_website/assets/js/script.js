/* ============================================
   DEN — Main JavaScript
   ============================================ */

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
        var downloadUrl = (data && data.apk_direct_url) ? data.apk_direct_url : null;
        var apkSize = (data && data.apk_size) ? data.apk_size : null;
        
        if (version) {
          document.querySelectorAll('.app-version').forEach(function (el) {
            el.textContent = version;
          });
        }

        if (apkSize) {
          document.querySelectorAll('.app-size').forEach(function (el) {
            el.textContent = apkSize;
          });
        }
        
        if (downloadUrl) {
          document.querySelectorAll('a[download]').forEach(function(el) {
             // Only update if it looks like an APK download button
             if (el.href && el.href.includes('.apk')) {
                 el.href = downloadUrl;
             }
          });
        }
      })
      .catch(function () {
        // Silently fail — fallback text in HTML remains visible
      });
  })();

  /* ── Navbar scroll state ── */
  const navbar = document.querySelector('.navbar');
  if (navbar) {
    const onScroll = () => {
      if (window.scrollY > 20) {
        navbar.classList.add('scrolled');
      } else {
        navbar.classList.remove('scrolled');
      }
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }

  /* ── Mobile nav toggle ── */
  const hamburger = document.querySelector('.nav-hamburger');
  const mobileNav = document.querySelector('.nav-mobile');

  if (hamburger && mobileNav) {
    hamburger.addEventListener('click', () => {
      const isOpen = hamburger.classList.toggle('open');
      mobileNav.classList.toggle('open', isOpen);
      document.body.style.overflow = isOpen ? 'hidden' : '';
    });

    // Close on link click
    mobileNav.querySelectorAll('a').forEach(link => {
      link.addEventListener('click', () => {
        hamburger.classList.remove('open');
        mobileNav.classList.remove('open');
        document.body.style.overflow = '';
      });
    });

    // Close on backdrop click
    mobileNav.addEventListener('click', (e) => {
      if (e.target === mobileNav) {
        hamburger.classList.remove('open');
        mobileNav.classList.remove('open');
        document.body.style.overflow = '';
      }
    });
  }

  /* ── Active nav link ── */
  const currentPath = window.location.pathname.split('/').pop() || 'index.html';
  document.querySelectorAll('.nav-links a, .nav-mobile a').forEach(link => {
    const href = link.getAttribute('href');
    if (href === currentPath || (currentPath === '' && href === 'index.html')) {
      link.classList.add('active');
    }
  });

  /* ── Scroll reveal ── */
  const revealEls = document.querySelectorAll('.reveal');
  if (revealEls.length > 0 && 'IntersectionObserver' in window) {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
          observer.unobserve(entry.target);
        }
      });
    }, {
      rootMargin: '0px 0px -60px 0px',
      threshold: 0.08
    });

    revealEls.forEach(el => observer.observe(el));
  } else {
    // Fallback: show everything
    revealEls.forEach(el => el.classList.add('visible'));
  }

  /* ── Contact form (demo only) ── */
  const contactForm = document.getElementById('contact-form');
  const formSuccess = document.getElementById('form-success');

  if (contactForm && formSuccess) {
    contactForm.addEventListener('submit', (e) => {
      e.preventDefault();

      const btn = contactForm.querySelector('[type="submit"]');
      btn.textContent = 'Sending…';
      btn.disabled = true;

      // Simulate async submit
      setTimeout(() => {
        contactForm.style.display = 'none';
        formSuccess.style.display = 'block';
      }, 1200);
    });
  }

  /* ── Smooth anchor scrolling ── */
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', (e) => {
      const target = document.querySelector(anchor.getAttribute('href'));
      if (target) {
        e.preventDefault();
        const offset = 80;
        const top = target.getBoundingClientRect().top + window.scrollY - offset;
        window.scrollTo({ top, behavior: 'smooth' });
      }
    });
  });

  /* ── Subtle parallax on hero glow ── */
  const heroGlows = document.querySelectorAll('.hero-glow');
  if (heroGlows.length > 0) {
    window.addEventListener('scroll', () => {
      const y = window.scrollY * 0.25;
      heroGlows.forEach((glow, i) => {
        glow.style.transform = `translateY(${i % 2 === 0 ? y : -y}px)`;
      });
    }, { passive: true });
  }

})();
