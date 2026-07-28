/* ─── Imperial & Metric Challenge · Site Includes ───
   Fetches header.html and footer.html and injects them into
   #site-header and #site-footer placeholders on every page.
   Place this script at the END of <body> on every page.       */

(function () {
    var BASE = '/';

    function load(id, file, callback) {
        var el = document.getElementById(id);
        if (!el) { if (callback) callback(); return; }
        fetch(BASE + file)
            .then(function (r) {
                if (!r.ok) throw new Error(file + ' not found');
                return r.text();
            })
            .then(function (html) {
                el.innerHTML = html;
                if (callback) callback();
            })
            .catch(function (err) {
                console.warn('Challenge includes:', err);
                if (callback) callback();
            });
    }

    function wireHamburger() {
        var burger = document.getElementById('hamburger');
        var navLinks = document.getElementById('navLinks');
        if (burger && navLinks) {
            burger.addEventListener('click', function () {
                navLinks.classList.toggle('open');
            });
        }
    }

    load('site-header', 'header.html', function () {
        wireHamburger();
        load('site-footer', 'footer.html');
    });
})();
