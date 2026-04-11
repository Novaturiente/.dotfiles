// ==UserScript==
// @name         Auto Cookie Consent
// @namespace    qutebrowser
// @match        *://*/*
// @run-at       document-end
// @grant        none
// ==/UserScript==

(function() {
    'use strict';
    const selectors = [
        '#onetrust-accept-btn-handler',
        '.cc-btn.cc-dismiss',
        '#CybotCookiebotDialogBodyLevelButtonLevelOptinAllowAll',
        '[data-testid="cookie-policy-manage-dialog-btn-accept-all"]',
        'button.accept-cookies',
        '#accept-cookie-consent',
        '.cookie-consent-accept',
        '#cookie-accept',
        '.js-cookie-consent-agree',
        '#gdpr-cookie-accept',
        '[aria-label="Accept cookies"]',
        '[aria-label="Accept all cookies"]',
        'button[data-cookiebanner="accept_button"]',
        '.fc-cta-consent',
        '#L2AGLb',
        '.cmpboxbtn.cmpboxbtnyes',
        '#didomi-notice-agree-button',
        '.message-component.message-button.no-children.focusable.sp_choice_type_11',
    ];

    function clickConsent() {
        for (const sel of selectors) {
            const el = document.querySelector(sel);
            if (el && el.offsetParent !== null) {
                el.click();
                return true;
            }
        }
        return false;
    }

    if (!clickConsent()) {
        let attempts = 0;
        const interval = setInterval(() => {
            if (clickConsent() || ++attempts > 10) clearInterval(interval);
        }, 500);
    }
})();
