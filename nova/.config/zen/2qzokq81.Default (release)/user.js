// Filtered port of cachyos-firefox-settings for Zen Browser.
// Source: /usr/lib/firefox/browser/defaults/preferences/cachyos.js (Firefox-only path).
//
// ponytail: user.js instead of /opt/zen-browser-bin/browser/defaults/preferences/ --
// survives package upgrades and needs no root or pacman hook. Ceiling: profile-scoped,
// so a new Zen profile needs this copied over. `locked` is not available in user.js,
// so every pref below stays editable in about:config.
//
// Excluded from upstream on purpose -- see the notes at the bottom of this file.

// ---------------------------------------------------------------------------
// Hardware acceleration (Intel Arc / Meteor Lake iGPU, VAAPI)
// ---------------------------------------------------------------------------
user_pref("media.hardware-video-decoding.force-enabled", true);
user_pref("media.gpu-process-decoder", true);
user_pref("media.webrtc.hw.h264.enabled", true);
user_pref("layers.gpu-process.enabled", true);
user_pref("gfx.webrender.all", true);
user_pref("gfx.webrender.precache-shaders", true);
user_pref("gfx.webrender.program-binary-disk", true);
user_pref("gfx.canvas.accelerated.cache-items", 32768);
user_pref("gfx.canvas.accelerated.cache-size", 4096);
user_pref("gfx.content.skia-font-cache-size", 80);

// ---------------------------------------------------------------------------
// Memory behaviour (tuned for 16 GB, not upstream's multi-GB media caches)
// ---------------------------------------------------------------------------
user_pref("browser.tabs.unloadOnLowMemory", true);
user_pref("image.mem.decode_bytes_at_a_time", 65536);
user_pref("image.mem.shared.unmap.min_expiration_ms", 120000);
user_pref("media.cache_readahead_limit", 7200);
user_pref("media.cache_resume_threshold", 3600);

// ---------------------------------------------------------------------------
// Network throughput
// ---------------------------------------------------------------------------
user_pref("network.dnsCacheExpiration", 3600);
user_pref("network.http.max-connections", 1800);
user_pref("network.http.max-persistent-connections-per-server", 10);
user_pref("network.http.max-urgent-start-excessive-connections-per-host", 5);
user_pref("network.http.pacing.requests.enabled", false);
user_pref("network.buffer.cache.size", 65535);
user_pref("network.ssl_tokens_cache_capacity", 32768);

// ---------------------------------------------------------------------------
// Telemetry and Mozilla phone-home
// ---------------------------------------------------------------------------
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("toolkit.telemetry.server", "data:,");
user_pref("toolkit.telemetry.coverage.opt-out", true);
user_pref("toolkit.coverage.opt-out", true);
user_pref("toolkit.coverage.endpoint.base", "");
user_pref("toolkit.contentRelevancy.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.usage.uploadEnabled", false);
user_pref("app.normandy.enabled", false);
user_pref("app.normandy.api_url", "");
user_pref("browser.ping-centre.telemetry", false);
user_pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);
user_pref("browser.tabs.crashReporting.sendReport", false);
user_pref("breakpad.reportURL", "");
user_pref("dom.private-attribution.submission.enabled", false);
user_pref("browser.discovery.enabled", false);
user_pref("browser.places.interactions.enabled", false);
user_pref("browser.search.serpEventTelemetryCategorization.enabled", false);
user_pref("security.certerrors.recordEventTelemetry", false);
user_pref("dom.security.unexpected_system_load_telemetry_enabled", false);

// ---------------------------------------------------------------------------
// Sponsored content, promos, and urlbar suggestion feeds
// ---------------------------------------------------------------------------
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.feeds.adsfeed", false);
user_pref("browser.newtabpage.activity-stream.trendingSearch.enabled", false);
user_pref("browser.newtabpage.activity-stream.unifiedAds.tiles.enabled", false);
user_pref("browser.newtabpage.activity-stream.unifiedAds.spocs.enabled", false);
user_pref("browser.urlbar.quicksuggest.enabled", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("browser.urlbar.suggest.trending", false);
user_pref("browser.urlbar.suggest.addons", false);
user_pref("browser.urlbar.weather.featureGate", false);
user_pref("browser.urlbar.yelp.featureGate", false);
user_pref("browser.urlbar.mdn.featureGate", false);
user_pref("browser.urlbar.fakespot.featureGate", false);
user_pref("browser.urlbar.pocket.featureGate", false);
user_pref("extensions.pocket.enabled", false);
user_pref("extensions.getAddons.showPane", false);
user_pref("extensions.getAddons.cache.enabled", false);
user_pref("extensions.htmlaboutaddons.recommendations.enabled", false);
user_pref("browser.shopping.experience2023.enabled", false);
user_pref("browser.vpn_promo.enabled", false);
user_pref("browser.privatebrowsing.vpnpromourl", "");
user_pref("browser.promo.pin.enabled", false);
user_pref("browser.promo.focus.enabled", false);
user_pref("browser.promo.cookiebanners.enabled", false);
user_pref("browser.uitour.enabled", false);
user_pref("browser.uitour.url", "");
user_pref("browser.contentblocking.report.lockwise.enabled", false);
user_pref("browser.contentblocking.report.monitor.enabled", false);
user_pref("browser.contentblocking.report.proxy.enabled", false);
user_pref("browser.contentblocking.report.hide_vpn_banner", true);
user_pref("browser.contentanalysis.enabled", false);
user_pref("signon.firefoxRelay.feature", "disabled");

// ---------------------------------------------------------------------------
// Privacy hardening
// ---------------------------------------------------------------------------
user_pref("browser.contentblocking.category", "strict");
user_pref("network.cookie.cookieBehavior.optInPartitioning", true);
user_pref("network.cookie.cookieBehavior.optInPartitioning.pbmode", true);
user_pref("dom.security.https_only_mode", true);
user_pref("media.autoplay.default", 5);
user_pref("network.predictor.enabled", false);
user_pref("network.predictor.enable-prefetch", false);
user_pref("network.prefetch-next", false);
user_pref("dom.push.enabled", false);
user_pref("devtools.debugger.remote-enabled", false);
user_pref("privacy.query_stripping.strip_list", "__hsfp __hssc __hstc __s _hsenc _openstat dclid fbclid gbraid gclid hsCtaTracking igshid mc_eid ml_subscriber ml_subscriber_hash msclkid oft_c oft_ck oft_d oft_id oft_ids oft_k oft_lk oft_sk oly_anon_id oly_enc_id rb_clickid s_cid twclid vero_conv vero_id wbraid wickedid yclid");
// Unbreak lists that pair with the "strict" category above.
user_pref("urlclassifier.features.socialtracking.skipURLs", "*.instagram.com, *.twitter.com, *.twimg.com");
user_pref("urlclassifier.trackingSkipURLs", "*.reddit.com, *.twitter.com, *.twimg.com");

// ---------------------------------------------------------------------------
// Certificate revocation: CRLite replaces per-visit OCSP lookups.
// Keep these four together -- dropping crlite while OCSP is off removes
// revocation checking entirely.
// ---------------------------------------------------------------------------
user_pref("security.OCSP.enabled", 0);
user_pref("security.pki.crlite_mode", 2);
user_pref("security.remote_settings.crlite_filters.enabled", true);
user_pref("services.settings.poll_interval", 300);

// ---------------------------------------------------------------------------
// Desktop integration (Wayland / niri / xdg-desktop-portal)
// ---------------------------------------------------------------------------
user_pref("widget.use-xdg-desktop-portal.file-picker", 1);
user_pref("browser.shell.checkDefaultBrowser", false);

// ---------------------------------------------------------------------------
// Window behaviour
// ---------------------------------------------------------------------------
// Zen mirrors a workspace's tabs into every window of that workspace, so a tab
// opened with --new-window also appears in the tab strip of the existing window
// (same zenSyncId, one logical tab shown twice). Disabling this restores
// conventional per-window tab sets.
// Checked on every sync path in modules/zen/ZenWindowSync.sys.mjs.
user_pref("zen.window-sync.enabled", false);

// ---------------------------------------------------------------------------
// DELIBERATELY NOT PORTED from cachyos.js
//
//   browser.cache.disk.enable=false, browser.cache.memory.capacity=1GB,
//   media.memory_cache_max_size=1GB, media.memory_caches_combined_limit_kb=3GB
//     -- trades 16 GB of RAM for disk cache on a DRAM-less NVMe. Not worth it.
//
//   browser.safebrowsing.* (~45 prefs, all disabled upstream)
//     -- removes malware and phishing download protection. Privacy win, security
//        loss. Add back if you would rather not talk to Google's list service.
//
//   extensions.blocklist.enabled=false
//     -- disables Mozilla's malicious-addon blocklist. Same trade, worse odds.
//
//   general.smoothScroll.msdPhysics.*, mousewheel.default.delta_multiplier_y=300
//     -- Zen ships its own scroll and animation tuning; these fight it.
//
//   browser.ml.* (chat, linkPreview, enable)
//     -- Zen builds features on this stack; blanket-disabling risks breaking them.
//
//   network.captive-portal-service.enabled=false, network.connectivity-service.enabled=false
//     -- breaks hotel and airport wifi login detection.
//
//   browser.newtabpage.enabled=false, browser.formfill.enable=false,
//   browser.download.start_downloads_in_tmp_dir=true
//     -- opinionated behaviour changes, not performance or privacy wins.
//
//   javascript.options.*.threshold, content.notify.interval
//     -- unmeasured JIT and reflow micro-tuning.
//
//   spellchecker.dictionary_path, extensions.autoDisableScopes, intl.locale.requested,
//   layout.css.grid-template-masonry-value
//     -- already handled by Zen, or Firefox-packaging specific.
// ---------------------------------------------------------------------------

// Catppuccin Mocha (Mauve): userChrome.css / userContent.css live in this
// profile's chrome/ dir; sources are vendored at system/themes/catppuccin/zen-browser/.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
