/* ─── Imperial & Metric Challenge · Site Includes ───
   Fetches header.html and footer.html and injects them into
   #site-header and #site-footer placeholders on every page.
   Place this script at the END of <body> on every page.

   By default #site-header loads the shared root /header.html. A
   section (e.g. /imperial/, /metric/) can use its own header
   instead by adding data-src="/imperial/header.html" to the
   #site-header element.                                          */

(function () {
    var BASE = '/';

    function load(id, file, callback) {
        var el = document.getElementById(id);
        if (!el) { if (callback) callback(); return; }
        var url = el.getAttribute('data-src') || (BASE + file);
        fetch(url)
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
