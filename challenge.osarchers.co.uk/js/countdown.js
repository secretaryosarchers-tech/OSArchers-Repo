/* ─── Countdown to the Imperial & Metric Challenge 2027 ─── */
(function () {
    var TARGET = new Date('2027-02-14T00:00:00Z').getTime();

    var els = {
        days: document.getElementById('cd-days'),
        hours: document.getElementById('cd-hours'),
        minutes: document.getElementById('cd-minutes'),
        seconds: document.getElementById('cd-seconds')
    };

    function pad(n) { return String(n).padStart(2, '0'); }

    function tick() {
        var diff = TARGET - Date.now();
        if (diff <= 0) {
            els.days.textContent = '00';
            els.hours.textContent = '00';
            els.minutes.textContent = '00';
            els.seconds.textContent = '00';
            clearInterval(timer);
            return;
        }
        var seconds = Math.floor(diff / 1000);
        var days = Math.floor(seconds / 86400);
        var hours = Math.floor((seconds % 86400) / 3600);
        var minutes = Math.floor((seconds % 3600) / 60);
        var secs = seconds % 60;

        els.days.textContent = pad(days);
        els.hours.textContent = pad(hours);
        els.minutes.textContent = pad(minutes);
        els.seconds.textContent = pad(secs);
    }

    if (els.days) {
        tick();
        var timer = setInterval(tick, 1000);
    }
})();
