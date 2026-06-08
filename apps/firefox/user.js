
/*

                                                                              [ Written by LOVE : 08-October-2022  ]
                                                                              [  last modified  : 08-November-2022 ]


####################################################################################################################
DISCLAIMER                                                                                                         #
####################################################################################################################
Only use a setting if you fully understand what it does and be especially wary of privacy-related preferences,
as you at worst make your browser less secure and easier to fingerprint.




####################################################################################################################
RESSOURCES                                                                                                         #
####################################################################################################################

https://github.com/arkenfox/user.js
https://github.com/pyllyukko/user.js
https://wiki.archlinux.org/title/Firefox/Privacy
https://brainfucksec.github.io/firefox-hardening-guide
https://mozillazine.org/
https://developer.mozilla.org/en-US/docs/Mozilla/Firefox/Experimental_features
https://mkaz.blog/misc/using-firefox-user-js-settings-file/
https://www.malekal.com/user-js-et-prefs-js-personnaliser-les-reglages-de-mozilla-firefox/
https://kb.mozillazine.org/User.js_file


####################################################################################################################
SECTIONS                                                                                                           #
####################################################################################################################

        - DISCLAIMER
        - RESSOURCES
        - about:config WARNING
        - STARTUP
        - DISABLE FIREFOX HOME CONTENT
        - RECOMMENDATIONS    (QUIETER FOX)
        - DISABLE Picture-in-picture
        - DISABLE FIREFOX SYNC
        - PASSWORDS
        - DISK AVOIDANCE
        - DOWNLOADS
        - HISTORY  (Settings > Privacy & security)
        - PB (Private Browsing) MODE
        - SHUTDOWN & SANITIZING
        - LOCATION BAR
        - HTTPS && MIXED CONTENTS
        - HEADERS / REFERERS
        - DOM (DOCUMENT OBJECT MODEL)
        - ETP (ENHANCED TRACKING PROTECTION)
        - RFP (RESIST FINGERPRINTING)
        - DISABLE APIs  (DON'T BOTHER)
        - BATTERY
        - SET DEFAULT PERMISSIONS  (DON'T BOTHER) (Settings > Privacy & security > Permissions)
        - DISABLE CLIPBOARD APIs  (DON'T BOTHER)
        - DISABLE POCKET (personal)
        - DISABLE SPELLCHECKER (personal)
        - STUDIES
        - CRASH REPORTS
        - TELEMETRY
        - DISABLE WEBRTC (Web Real-Time Communication)
        - DISABLE WebAssembly
        - DISABLE JavaScript in pdfs (the native PDF viewer of the browser)
        - NOTIFICATIONS
        - SPOOF YOUR BROWSER PLATFORM  (Need to diable the rfp=resist fingerprinting)
        - UI CUSTOMIZATION
        - DON'T TOUCH (Prefereneces set by default and shold not be changed)
        - ADDITIONAL
        - DEPRECATED / REMOVED / LEGACY / RENAMED
*/


/*
####################################################################################################################
[SECTION 0000]: about:config WARNING                                                                               #
####################################################################################################################
*/

/* 0000: disable about:config warning ***/
user_pref("browser.aboutConfig.showWarning", false);


/*
####################################################################################################################
[SECTION 0100]: STARTUP                                                                                            #
####################################################################################################################
*/


/* 0101: disable default browser check
 * [SETTING] General>Startup>Always check if Firefox is your default browser ***/
user_pref("browser.shell.checkDefaultBrowser", false);

/* 0102: set startup page [SETUP-CHROME]
 * 0=blank, 1=home, 2=last visited page, 3=resume previous session
 * [NOTE] Session Restore is cleared with history (2811), and not used in Private Browsing mode
 * [SETTING] General>Startup>Restore previous session ***/
user_pref("browser.startup.page", 0);


/* 0103: set HOME+NEWWINDOW page
 * about:home=Firefox Home (default, see 0105), custom URL, about:blank
 * [SETTING] Home>New Windows and Tabs>Homepage and new windows ***/
user_pref("browser.startup.homepage", "about:blank");

/* 0104: set NEWTAB page
 * true=Firefox Home (default, see 0105), false=blank page
 * [SETTING] Home>New Windows and Tabs>New tabs ***/
user_pref("browser.newtabpage.enabled", false);

/* 0105: disable sponsored content on Firefox Home (Activity Stream)
 * [SETTING] Home>Firefox Home Content ***/
user_pref("browser.newtabpage.activity-stream.showSponsored", false); // [FF58+] Pocket > Sponsored Stories
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false); // [FF83+] Sponsored shortcuts

/* 0106: clear default topsites
 * [NOTE] This does not block you from adding your own ***/
user_pref("browser.newtabpage.activity-stream.default.sites", "");



/*
####################################################################################################################
[SECTION 0300]: Disable confirm before quiting with Ctrl + Q (Quiting multiple tabs)                               #
####################################################################################################################
*/

// Settings > General > Confirm before quiting with Ctrl + Q
user_pref("browser.warnOnQuitShortcut", false);



/*
####################################################################################################################
[SECTION 0300]: DISABLE FIREFOX HOME CONTENT                                                                       #
####################################################################################################################
*/

user_pref("browser.newtabpage.activity-stream.showSearch", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.section.highlights.includeVisited", false);
user_pref("browser.newtabpage.activity-stream.section.highlights.includeBookmarks", false);
user_pref("browser.newtabpage.activity-stream.section.highlights.includeDownloads", false);


/*
####################################################################################################################
[SECTION 0300]: RECOMMENDATIONS    (QUIETER FOX)                                                                   #
####################################################################################################################
*/

/* 0320: disable recommendation pane in about:addons (uses Google Analytics) ***/
user_pref("extensions.getAddons.showPane", false); // [HIDDEN PREF]

/* 0321: disable recommendations in about:addons' Extensions and Themes panes [FF68+] ***/
user_pref("extensions.htmlaboutaddons.recommendations.enabled", false);

/* 0322: disable personalized Extension Recommendations in about:addons and AMO [FF65+]
 * [NOTE] This pref has no effect when Health Reports (0331) are disabled
 * [SETTING] Privacy & Security>Firefox Data Collection & Use>Allow Firefox to make personalized extension recommendations
 * [1] https://support.mozilla.org/kb/personalized-extension-recommendations ***/
user_pref("browser.discovery.enabled", false);


/* Do not recommend extensions/addons while browsing */
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);

/* Do not recommend feautures while browsing */
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);


/*
####################################################################################################################
[SECTION xxxx]: DISABLE Picture-in-picture                                                                         #
####################################################################################################################
*/

user_pref("media.videocontrols.picture-in-picture.video-toggle.enabled", false);


/*
####################################################################################################################
[SECTION xxxx]: DISABLE FIREFOX SYNC                                                                               #
####################################################################################################################
*/

user_pref("identity.fxaccounts.enabled", false);


/*
####################################################################################################################
[SECTION 0900]: PASSWORDS                                                                                          #
####################################################################################################################
*/



/* 0903: disable auto-filling username & password form fields
 * can leak in cross-site forms *and* be spoofed
 * [NOTE] Username & password is still available when you enter the field
 * [SETTING] Privacy & Security>Logins and Passwords>Autofill logins and passwords
 * [1] https://freedom-to-tinker.com/2017/12/27/no-boundaries-for-user-identities-web-trackers-exploit-browser-login-managers/
 * [2] https://homes.esat.kuleuven.be/~asenol/leaky-forms/ ***/

user_pref("signon.autofillForms", false);


/* 0904: disable formless login capture for Password Manager [FF51+] ***/
user_pref("signon.formlessCapture.enabled", false);


/* 0905: limit (or disable) HTTP authentication credentials dialogs triggered by sub-resources [FF41+]
 * hardens against potential credentials phishing
 * 0 = don't allow sub-resources to open HTTP authentication credentials dialogs
 * 1 = don't allow cross-origin sub-resources to open HTTP authentication credentials dialogs
 * 2 = allow sub-resources to open HTTP authentication credentials dialogs (default) ***/

user_pref("network.auth.subresource-http-auth-allow", 1);


/* 0906: enforce no automatic authentication on Microsoft sites [FF91+] [WINDOWS 10+]
 * [SETTING] Privacy & Security>Logins and Passwords>Allow Windows single sign-on for...
 * [1] https://support.mozilla.org/kb/windows-sso ***/
   // user_pref("network.http.windows-sso.enabled", false); // [DEFAULT: false]


/* 5003: disable saving passwords
 * [NOTE] This does not clear any passwords already saved
 * [SETTING] Privacy & Security>Logins and Passwords>Ask to save logins and passwords for websites ***/
user_pref("signon.rememberSignons", false);
user_pref("signon.generation.enabled", false);
user_pref("signon.management.page.breach-alerts.enabled", false);




/*
####################################################################################################################
[SECTION 1000]: DISK AVOIDANCE                                                                                     #
####################################################################################################################
*/



/* 1001: disable disk cache
 * [SETUP-CHROME] If you think disk cache helps perf, then feel free to override this
 * [NOTE] We also clear cache on exit (2811) ***/
user_pref("browser.cache.disk.enable", false);

/* 1002: disable media cache from writing to disk in Private Browsing
 * [NOTE] MSE (Media Source Extensions) are already stored in-memory in PB ***/
user_pref("browser.privatebrowsing.forceMediaMemoryCache", true); // [FF75+]
//user_pref("media.memory_cache_max_size", 65536);

/* 1003: disable storing extra session data [SETUP-CHROME]
 * define on which sites to save extra session data such as form content, cookies and POST data
 * 0=everywhere, 1=unencrypted sites, 2=nowhere ***/
user_pref("browser.sessionstore.privacy_level", 2);

/* 1006: disable favicons in shortcuts
 * URL shortcuts use a cached randomly named .ico file which is stored in your
 * profile/shortcutCache directory. The .ico remains after the shortcut is deleted
 * If set to false then the shortcuts use a generic Firefox icon ***/
user_pref("browser.shell.shortcutFavicons", false);


/*
####################################################################################################################
[SECTION 2600]: DOWNLOADS                                                                                          #
####################################################################################################################
*/


/* 2651: enable user interaction for security by always asking where to download
 * [SETUP-CHROME] On Android this blocks longtapping and saving images
 * [SETTING] General>Downloads>Always ask you where to save files ***/
user_pref("browser.download.useDownloadDir", false);


/* 2653: disable adding downloads to the system's "recent documents" list ***/
user_pref("browser.download.manager.addToRecentDocs", false);


/* 2654: enable user interaction for security by always asking how to handle new mimetypes [FF101+]
 * [SETTING] General>Files and Applications>What should Firefox do with other files ***/
user_pref("browser.download.always_ask_before_handling_new_types", true);


/*
####################################################################################################################
[SECTION xxxx]: HISTORY  (Settings > Privacy & security)                                                           #
####################################################################################################################
*/


// Do not Remember browsing and download history
/* [NOTE] We also clear history and downloads on exit (2811)*/
user_pref("places.history.enabled", false);


// Do not Remember search and form history
/* [SETUP-WEB] Be aware that autocomplete form data can be read by third parties [1][2]
 * [NOTE] We also clear formdata on exit (2811)
 * [SETTING] Privacy & Security>History>Custom Settings>Remember search and form history
 * [1] https://blog.mindedsecurity.com/2011/10/autocompleteagain.html
 * [2] https://bugzilla.mozilla.org/381681 */
 user_pref("browser.formfill.enable", false);


 // Clear history when Firefox closes
/*  enable Firefox to clear items on shutdown/on exit
 *  [SETTING] Privacy & Security>History>Custom Settings>Clear history when Firefox closes | Settings ***/
user_pref("privacy.sanitize.sanitizeOnShutdown", true);



/*
####################################################################################################################
[SECTION 5000]: PB (Private Browsing) MODE                                                                         #
####################################################################################################################
*/


/* 5001: start Firefox in PB (Private Browsing) mode
 * [NOTE] In this mode all windows are "private windows" and the PB mode icon is not displayed
 * [NOTE] The P in PB mode can be misleading: it means no "persistent" disk state such as history,
 * caches, searches, cookies, localStorage, IndexedDB etc (which you can achieve in normal mode).
 * In fact, PB mode limits or removes the ability to control some of these, and you need to quit
 * Firefox to clear them. PB is best used as a one off window (Menu>New Private Window) to provide
 * a temporary self-contained new session. Close all Private Windows to clear the PB mode session.
 * [SETTING] Privacy & Security>History>Custom Settings>Always use private browsing mode
 * [1] https://wiki.mozilla.org/Private_Browsing
 * [2] https://support.mozilla.org/kb/common-myths-about-private-browsing ***/
user_pref("browser.privatebrowsing.autostart", true);



/* 5007: exclude "Undo Closed Tabs" in Session Restore ***/
//Even with Firefox set to not remember history,
//your closed tabs are stored temporarily at Menu -> History -> Recently Closed Tabs.
//This means no more: Ctrl + Shift + t
user_pref("browser.sessionstore.max_tabs_undo", 0);


/*
####################################################################################################################
[SECTION 2800]: SHUTDOWN & SANITIZING                                                                              #
####################################################################################################################
*/


/** SANITIZE ON SHUTDOWN: IGNORES "ALLOW" SITE EXCEPTIONS ***/
/* 2811: set/enforce what items to clear on shutdown (if 2810 is true) [SETUP-CHROME]
 * [NOTE] If "history" is true, downloads will also be cleared
 * [NOTE] "sessions": Active Logins: refers to HTTP Basic Authentication [1], not logins via cookies
 * [1] https://en.wikipedia.org/wiki/Basic_access_authentication ***/
 user_pref("privacy.clearOnShutdown.cache", true);     // [DEFAULT: true]
 user_pref("privacy.clearOnShutdown.downloads", true); // [DEFAULT: true]
 user_pref("privacy.clearOnShutdown.formdata", true);  // [DEFAULT: true]
 user_pref("privacy.clearOnShutdown.history", true);   // [DEFAULT: true]
 user_pref("privacy.clearOnShutdown.sessions", true);  // [DEFAULT: true]
    // user_pref("privacy.clearOnShutdown.siteSettings", false); // [DEFAULT: false]
 /* 2812: set Session Restore to clear on shutdown (if 2810 is true) [FF34+]
  * [NOTE] Not needed if Session Restore is not used (0102) or it is already cleared with history (2811)
  * [NOTE] If true, this prevents resuming from crashes (also see 5008) ***/
    // user_pref("privacy.clearOnShutdown.openWindows", true);

 /** SANITIZE ON SHUTDOWN: RESPECTS "ALLOW" SITE EXCEPTIONS FF103+ ***/
 /* 2815: set "Cookies" and "Site Data" to clear on shutdown (if 2810 is true) [SETUP-CHROME]
  * [NOTE] Exceptions: A "cookie" block permission also controls "offlineApps" (see note below).
  * serviceWorkers require an "Allow" permission. For cross-domain logins, add exceptions for
  * both sites e.g. https://www.youtube.com (site) + https://accounts.google.com (single sign on)
  * [NOTE] "offlineApps": Offline Website Data: localStorage, service worker cache, QuotaManager (IndexedDB, asm-cache)
  * [WARNING] Be selective with what sites you "Allow", as they also disable partitioning (1767271)
  * [SETTING] to add site exceptions: Ctrl+I>Permissions>Cookies>Allow (when on the website in question)
  * [SETTING] to manage site exceptions: Options>Privacy & Security>Permissions>Settings ***/
 user_pref("privacy.clearOnShutdown.cookies", true); // Cookies
 user_pref("privacy.clearOnShutdown.offlineApps", true); // Site Data


 /* 2816: set cache to clear on exit [FF96+]
  * [NOTE] We already disable disk cache (1001) and clear on exit (2811) which is more robust
  * [1] https://bugzilla.mozilla.org/1671182 ***/
    // user_pref("privacy.clearsitedata.cache.enabled", true);




/* 2822: reset default "Time range to clear" for "Clear Recent History" (2820)
 * Firefox remembers your last choice. This will reset the value when you start Firefox
 * 0=everything, 1=last hour, 2=last two hours, 3=last four hours, 4=today
 * [NOTE] Values 5 (last 5 minutes) and 6 (last 24 hours) are not listed in the dropdown,
 * which will display a blank value, and are not guaranteed to work ***/
user_pref("privacy.sanitize.timeSpan", 0);



/** SANITIZE MANUAL: IGNORES "ALLOW" SITE EXCEPTIONS ***/
/* 2820: reset default items to clear with Ctrl-Shift-Del [SETUP-CHROME]
// Check all the boxes by default in "Clear Recent History" when pressing Ctrl+Shift+H
 * This dialog can also be accessed from the menu History>Clear Recent History
 * Firefox remembers your last choices. This will reset them when you start Firefox
 * [NOTE] Regardless of what you set "downloads" to, as soon as the dialog
 * for "Clear Recent History" is opened, it is synced to the same as "history" ***/
user_pref("privacy.cpd.cache", true);    // [DEFAULT: true]
user_pref("privacy.cpd.formdata", true); // [DEFAULT: true]
user_pref("privacy.cpd.history", true);  // [DEFAULT: true]
user_pref("privacy.cpd.sessions", true); // [DEFAULT: true]
user_pref("privacy.cpd.offlineApps", false); // [DEFAULT: false]
user_pref("privacy.cpd.cookies", false);
   // user_pref("privacy.cpd.downloads", true); // not used, see note above
   // user_pref("privacy.cpd.openWindows", false); // Session Restore
   // user_pref("privacy.cpd.passwords", false);
   // user_pref("privacy.cpd.siteSettings", false);



/*
####################################################################################################################
[SECTION xxxx]: LOCATION BAR                                                                                       #
####################################################################################################################
*/


/* 5010: disable location bar suggestion types
 * [SETTING] Privacy & Security>Address Bar>When using the address bar, suggest ***/
user_pref("browser.urlbar.suggest.history", false);
user_pref("browser.urlbar.suggest.bookmark", false);
user_pref("browser.urlbar.suggest.openpage", false);
user_pref("browser.urlbar.suggest.topsites", false); // [FF78+]
user_pref("browser.urlbar.suggest.engines", false);  //personal
user_pref("browser.urlbar.suggest.searches", false);  //personal
user_pref("browser.urlbar.suggest.bestmatch", false);  //personal
user_pref("browser.urlbar.suggest.remotetab", false);  //personal

user_pref("browser.urlbar.showSearchSuggestionsFirst", false);  //personal

/* 0801: disable location bar using search
 * Don't leak URL typos to a search engine, give an error message instead
 * Examples: "secretplace,com", "secretplace/com", "secretplace com", "secret place.com"
 * [NOTE] This does not affect explicit user action such as using search buttons in the
 * dropdown, or using keyword search shortcuts you configure in options (e.g. "d" for DuckDuckGo)
 * [SETUP-CHROME] Override this if you trust and use a privacy respecting search engine ***/
user_pref("keyword.enabled", false);

/* 0802: disable location bar domain guessing
 * domain guessing intercepts DNS "hostname not found errors" and resends a
 * request (e.g. by adding www or .com). This is inconsistent use (e.g. FQDNs), does not work
 * via Proxy Servers (different error), is a flawed use of DNS (TLDs: why treat .com
 * as the 411 for DNS errors?), privacy issues (why connect to sites you didn't
 * intend to), can leak sensitive data (e.g. query strings: e.g. Princeton attack),
 * and is a security risk (e.g. common typos & malicious sites set up to exploit this) ***/
user_pref("browser.fixup.alternate.enabled", false); // [DEFAULT: false FF104+]


/* 0804: disable live search suggestions
 * [NOTE] Both must be true for the location bar to work
 * [SETUP-CHROME] Override these if you trust and use a privacy respecting search engine
 * [SETTING] Search>Provide search suggestions | Show search suggestions in address bar results ***/
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.suggest.searches", false);


/* 0805: disable location bar making speculative connections [FF56+]
 * [1] https://bugzilla.mozilla.org/1348275 ***/
user_pref("browser.urlbar.speculativeConnect.enabled", false);


 /* 0806: disable location bar leaking single words to a DNS provider **after searching** [FF78+]
  * 0=never resolve, 1=use heuristics, 2=always resolve
  * [1] https://bugzilla.mozilla.org/1642623 ***/
 user_pref("browser.urlbar.dnsResolveSingleWordsAfterSearch", 0); // [DEFAULT: 0 FF104+]


 /* 0807: disable location bar contextual suggestions [FF92+]
  * [SETTING] Privacy & Security>Address Bar>Suggestions from...
  * [1] https://blog.mozilla.org/data/2021/09/15/data-and-firefox-suggest/ ***/
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false); // [FF95+]
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);





/*
####################################################################################################################
[SECTION 1200]: HTTPS && MIXED CONTENTS                                                                            #
####################################################################################################################
*/


/* 1241: disable insecure passive content (such as images) on https pages [SETUP-WEB]

More and more websites are offering their services over the encrypted HTTPS protocol.
Accessing websites over HTTPS increases your online security as all the data transfer takes place over an
encrypted connection.

But cyber-criminals sometimes place HTTP content inside in order to attack the unsuspecting user through
the phishing sites.

If a webpage is showing HTTPS and HTTP content together, then it is said to have mixed content.

If you are a Firefox user, then you can block these mixed content objects to boost your security
when accessing secure websites.

There are two types of mixed contents
– active mixed content and passive mixed content.

The active mixed content is made up of scripts while the passive mixed content is made up of images, videos
and other display media items.

By default, Firefox blocks only active mixed content and allows the display mixed content.
//user_pref("security.mixed_content.block_display_content", true);

Usually this setting is good enough for most of the users.
But if you want to beef up your security even more, then you can block the passive mixed content as well.
***/
user_pref("security.mixed_content.block_display_content", true);


/* Block plain text requests from Flash on encrypted pages
In order to help mitigate man-in-the-middle (MitM) attacks caused by Flash content on encrypted pages,
a preference has been added to treat OBJECT_SUBREQUESTs as active content.
See bug 1190623 for more details.
*/
user_pref("security.mixed_content.block_object_subrequest", true);



/*Upgrading mixed display content
  When enabled, this preference causes Firefox to automatically upgrade requests for media content from
  HTTP to HTTPS on secure pages.
  The intent is to prevent mixed-content conditions in which some content is loaded securely while other
  content is insecure. If the upgrade fails (because the media's host doesn't support HTTPS),
  the media is not loaded. (See bug 1435733 for more details.)
  This also changes the console warning; if the upgrade succeeds, the message indicates that the request
  was upgraded, instead of showing a warning.
 */

//user_pref("security.mixed_content.upgrade_display_content", true);



/* 1244: enable HTTPS-Only mode in all windows [FF76+]
 * When the top-level is HTTPS, insecure subresources are also upgraded (silent fail)
 * [SETTING] to add site exceptions: Padlock>HTTPS-Only mode>On (after "Continue to HTTP Site")
 * [SETTING] Privacy & Security>HTTPS-Only Mode (and manage exceptions)
 * [TEST] http://example.com [upgrade]
 * [TEST] http://httpforever.com/ [no upgrade] ***/
 user_pref("dom.security.https_only_mode", true); // [FF76+]

 /* 1246: disable HTTP background requests [FF82+]
 * When attempting to upgrade, if the server doesn't respond within 3 seconds, Firefox sends
 * a top-level HTTP request without path in order to check if the server supports HTTPS or not
 * This is done to avoid waiting for a timeout which takes 90 seconds
 * [1] https://bugzilla.mozilla.org/buglist.cgi?bug_id=1642387,1660945 ***/
user_pref("dom.security.https_only_mode_send_http_background_request", false);

/*
FURTHER EXPLANATION:
If you are like me you probably thought that 'HTTPS-only' mode meant that Firefox would only ever transmit
your data securely unless you explicitly dismiss the warning screen.
Well... HTTPS-only mode has an intentional 'background HTTP' mechanism: When a page that was implicitly
upgraded to HTTPS takes longer than 3 seconds to load, Firefox will send the request again over unencrypted HTTP,
BEFORE showing you the warning screen.
This is done so they can show the warning screen faster instead of waiting for the network timeout.
Unfortunately, this is trivially exploitable by an attacker.
Delay the HTTPS request for some seconds, for example by overloading the network or doing a MITM attack.
Then Firefox will spill the request in plain text for everyone on the network to see.

This is a not huge issue, since it only affects implicity upgraded requests and only top-level navigations
(no subresources loaded over http), but it may be something that is unexpected for you.
*/



/*
####################################################################################################################
[SECTION 1600]: HEADERS / REFERERS                                                                                 #
####################################################################################################################


                  full URI: https://example.com:8888/foo/bar.html?id=1234
     scheme+host+port+path: https://example.com:8888/foo/bar.html
          scheme+host+port: https://example.com:8888

   [1] https://feeding.cloud.geek.nz/posts/tweaking-referrer-for-privacy-in-firefox/

####################################################################################################################
*/


/* 1601: control when to send a cross-origin referer
 * [SETUP-WEB] Breakage: older modems/routers and some sites e.g banks, vimeo, icloud, instagram
 * If "2" is too strict, then override to "0" and use Smart Referer extension (Strict mode + add exceptions)
       0 = Send Referer in all cases/always (default)
       1 = Send Referer to same eTLD sites (only if base domains match)
       2 = Send Referer only when the full hostnames match
        ***/
// Note: if you notice significant breakage,you might try 1 combined with an XOriginTrimmingPolicy tweak
user_pref("network.http.referer.XOriginPolicy", 2);


/* 1602: control the amount of cross-origin information to send [FF52+]
   When sending Referer across origins, only send: scheme, host, and port in the Referer header
   of cross-origin requests.
       0 = Send full url in Referer (default)
       1 = Send url without query string in Referer (scheme+host+port+path)
       2 = Only send scheme, host, and port in Referer (scheme+host+port)
   ***/
user_pref("network.http.referer.XOriginTrimmingPolicy", 2);


// Disable HTTP referer
//HTTP referer is an optional HTTP header field that identifies the address of the
//previous webpage from which a link to the currently requested page was followed.

/* 7007: referers
 * [WHY] Only cross-origin referers (1600s) need control
   0: Never send the Referer header or set document.referrer.
   1: Send the Referer header when clicking on a link, and set document.referrer for the following page.
   2: Send the Referer header when clicking on a link or loading an image, and set document.referrer for the following page. (Default)
***/
// user_pref("network.http.sendRefererHeader", 2);
// user_pref("network.http.referer.trimmingPolicy", 0)


/* 7015: enable the DNT (Do Not Track) HTTP header
 * [WHY] DNT is enforced with Tracking Protection which is used in ETP Strict (2701) ***/
   // user_pref("privacy.donottrackheader.enabled", true);


/*
####################################################################################################################
[SECTION 2400]: DOM (DOCUMENT OBJECT MODEL)                                                                        #
####################################################################################################################
*/

 /* 2403: block popup windows
 * [SETTING] Privacy & Security>Permissions>Block pop-up windows ***/
user_pref("dom.disable_open_during_load", true);



/*
####################################################################################################################
[SECTION 2700]: ETP (ENHANCED TRACKING PROTECTION)                                                                 #
####################################################################################################################
*/


/* 2701: enable ETP Strict Mode [FF86+]
 * ETP Strict Mode enables Total Cookie Protection (TCP)
 * [NOTE] Adding site exceptions disables all ETP protections for that site and increases the risk of
 * cross-site state tracking e.g. exceptions for SiteA and SiteB means PartyC on both sites is shared
 * [1] https://blog.mozilla.org/security/2021/02/23/total-cookie-protection/
 * [SETTING] to add site exceptions: Urlbar>ETP Shield
 * [SETTING] to manage site exceptions: Options>Privacy & Security>Enhanced Tracking Protection>Manage Exceptions ***/
user_pref("browser.contentblocking.category", "strict");




/*
####################################################################################################################
[SECTION 4500]: RFP (RESIST FINGERPRINTING)                                                                        #
####################################################################################################################
*/


/* 4501: enable privacy.resistFingerprinting [FF41+]
 * [SETUP-WEB] RFP can cause some website breakage: mainly canvas, use a site exception via the urlbar
 * RFP also has a few side effects: mainly timezone is UTC0, and websites will prefer light theme
 * [1] https://bugzilla.mozilla.org/418986 ***/
 user_pref("privacy.resistFingerprinting", true);


/* 4510: disable using system colors
 * [SETTING] General>Language and Appearance>Fonts and Colors>Colors>Use system colors ***/
user_pref("browser.display.use_system_colors", false); // [DEFAULT: false NON-WINDOWS]


/* 4512: enforce links targeting new windows to open in a new tab instead
 * 1=most recent window or tab, 2=new window, 3=new tab
 * Stops malicious window sizes and some screen resolution leaks.
 * You can still right-click a link and open in a new window
 * [SETTING] General>Tabs>Open links in tabs instead of new windows
 * [TEST] https://arkenfox.github.io/TZP/tzp.html#screen
 * [1] https://gitlab.torproject.org/tpo/applications/tor-browser/-/issues/9881 ***/
 user_pref("browser.link.open_newwindow", 3); // [DEFAULT: 3]


 /* 4520: disable WebGL (Web Graphics Library)
 * [SETUP-WEB] If you need it then override it. RFP still randomizes canvas for naive scripts ***/
user_pref("webgl.disabled", true);
user_pref("webgl.enable-webgl2", false);  //personal




/*
####################################################################################################################
[SECTION 7001]: DISABLE APIs  (DON'T BOTHER)                                                                       #
####################################################################################################################
*/

/*
 * Location-Aware Browsing, Full Screen, offline cache (appCache), Virtual Reality
 * [WHY] The API state is easily fingerprintable. Geo and VR are behind prompts (7002).
 * appCache storage capability was removed in FF90. Full screen requires user interaction ***/

//NOTE: This may break websites that needs access to your location.
//One may want to simply allow location-access per site, instead of disabling this feature completely.
user_pref("geo.enabled", false);

   // user_pref("full-screen-api.enabled", false);
   // user_pref("browser.cache.offline.enable", false);
   // user_pref("dom.vr.enabled", false); // [DEFAULT: false FF97+]


/*
####################################################################################################################
[SECTION xxxx]: BATTERY                                                                                            #
####################################################################################################################
*/


// Website owners can track the battery status of your device.  (*o*)
user_pref("dom.battery.enabled", false);



/*
####################################################################################################################
[SECTION 7002]: SET DEFAULT PERMISSIONS  (DON'T BOTHER) (Settings > Privacy & security > Permissions)              #
####################################################################################################################

Location, Camera, Microphone, Notifications [FF58+] Virtual Reality [FF73+]
0=always ask (default), 1=allow, 2=block
[WHY] These are fingerprintable via Permissions API, except VR. Just add site
exceptions as allow/block for frequently visited/annoying sites: i.e. not global
[SETTING] to add site exceptions: Ctrl+I>Permissions>
[SETTING] to manage site exceptions: Options>Privacy & Security>Permissions>Settings

####################################################################################################################
*/

user_pref("permissions.default.geo", 2);
user_pref("permissions.default.camera", 2);
user_pref("permissions.default.microphone", 2);
user_pref("permissions.default.desktop-notification", 2);
user_pref("permissions.default.xr", 2); // Virtual Reality

/*STOP AUTOPLAY (personal) */
user_pref("media.autoplay.default", 5);   // 0:allow;1:blockAudible;2:Prompt;5:blockAll     //personal
user_pref("media.autoplay.blocking_policy", 2);                                             //personal
user_pref("media.autoplay.allow-extension-background-pages", false);                        //personal
user_pref("media.autoplay.block-event.enabled", true);                                      //personal



/*
####################################################################################################################
[SECTION 7013]: DISABLE CLIPBOARD APIs  (DON'T BOTHER)                                                             #
####################################################################################################################
*/

/* 7013: disable  API
 * [WHY] Fingerprintable. Breakage. Cut/copy/paste require user
 * interaction, and paste is limited to focused editable fields
   Disable that websites can get notifications if you copy, paste, or cut something from a web page,
   and it lets them know which part of the page had been selected.
 * ***/
user_pref("dom.event.clipboardevents.enabled", false);



/* 7016: customize ETP (Enhanced Tracking Protection) settings
 * [WHY] Arkenfox only supports strict (2701) which sets these at runtime ***/
   // user_pref("network.cookie.cookieBehavior", 5); // [DEFAULT: 5 FF103+]
   // user_pref("network.http.referer.disallowCrossSiteRelaxingDefault", true);
   // user_pref("network.http.referer.disallowCrossSiteRelaxingDefault.top_navigation", true); // [FF100+]
   // user_pref("privacy.partition.network_state.ocsp_cache", true);
   // user_pref("privacy.query_stripping.enabled", true); // [FF101+] [ETP FF102+]

//A result of the Tor Uplift effort, this preference makes Firefox more resistant to browser fingerprinting.
user_pref("privacy.trackingprotection.enabled", true);

   // user_pref("privacy.trackingprotection.socialtracking.enabled", true);
   // user_pref("privacy.trackingprotection.cryptomining.enabled", true); // [DEFAULT: true]
   // user_pref("privacy.trackingprotection.fingerprinting.enabled", true); // [DEFAULT: true]

/* 7017: disable service workers
 * [WHY] Already isolated (FF96+) with TCP (2701) behind a pref (2710)
 * or blocked with TCP in 3rd parties (FF95 or lower) ***/
   // user_pref("dom.serviceWorkers.enabled", false);

/* 7018: disable Web Notifications
 * [WHY] Web Notifications are behind a prompt (7002)
 * [1] https://blog.mozilla.org/en/products/firefox/block-notification-requests/ ***/
   // user_pref("dom.webnotifications.enabled", false); // [FF22+]
   // user_pref("dom.webnotifications.serviceworker.enabled", false); // [FF44+]

/* 7019: disable Push Notifications [FF44+]
 * [WHY] Push requires subscription
 * [NOTE] To remove all subscriptions, reset "dom.push.userAgentID"
 * [1] https://support.mozilla.org/kb/push-notifications-firefox ***/
   // user_pref("dom.push.enabled", false);


/*
####################################################################################################################
[SECTION 7013]: DISABLE POCKET (personal)                                                                          #
####################################################################################################################
*/

user_pref("extensions.pocket.enabled", false);         // personal
user_pref("extensions.pocket.onSaveRecs", false);      // personal


/*
####################################################################################################################
[SECTION 7013]: DISABLE SPELLCHECKER (personal)                                                                    #
####################################################################################################################
*/

user_pref("layout.spellcheckDefault", 0);  // Possible values: 0, 1, 2


/*
####################################################################################################################
[SECTION xxxx]: STUDIES                                                                                            #
####################################################################################################################
*/


/* 0340: disable Studies
* [SETTING] Privacy & Security>Firefox Data Collection & Use>Allow Firefox to install and run studies ***/
user_pref("app.shield.optoutstudies.enabled", false);


/* 0341: disable Normandy/Shield [FF60+]
 * Shield is a telemetry system that can push and test "recipes"
 * [1] https://mozilla.github.io/normandy/
 * https://wiki.mozilla.org/Firefox/Normandy/PreferenceRollout
 ***/
 user_pref("app.normandy.enabled", false);
 user_pref("app.normandy.api_url", "");



/*
####################################################################################################################
[SECTION xxxx]: CRASH REPORTS                                                                                      #
####################################################################################################################
*/

/* 0350: disable Crash Reports ***/
user_pref("breakpad.reportURL", "");
user_pref("browser.tabs.crashReporting.sendReport", false); // [FF44+]
   // user_pref("browser.crashReports.unsubmittedCheck.enabled", false); // [FF51+] [DEFAULT: false]

/* 0351: enforce no submission of backlogged Crash Reports [FF58+]
 * [SETTING] Privacy & Security>Firefox Data Collection & Use>Allow Firefox to send backlogged crash reports  ***/
user_pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false); // [DEFAULT: false]



/*
####################################################################################################################
[SECTION xxxx]: TELEMETRY                                                                                          #
####################################################################################################################
*/


/* 0330: disable new data submission [FF41+]
 * If disabled, no policy is shown or upload takes place, ever
 * [1] https://bugzilla.mozilla.org/1195552 ***/
 //user_pref("datareporting.policy.dataSubmissionEnabled", false);

 /* 0331: disable Health Reports
  [SETTING] Privacy & Security>Firefox Data Collection & Use>Allow Firefox to send technical and interaction
  data to Mozilla ***/
 user_pref("datareporting.healthreport.uploadEnabled", false);

 /* 0332: disable telemetry
  * The "unified" pref affects the behavior of the "enabled" pref
  * - If "unified" is false then "enabled" controls the telemetry module
  * - If "unified" is true then "enabled" only controls whether to record extended data
  * [NOTE] "toolkit.telemetry.enabled" is now LOCKED to reflect prerelease (true) or release builds (false) [2]
  * [1] https://firefox-source-docs.mozilla.org/toolkit/components/telemetry/telemetry/internals/preferences.html
  * [2] https://medium.com/georg-fritzsche/data-preference-changes-in-firefox-58-2d5df9c428b5 ***/

 //user_pref("toolkit.telemetry.unified", false);
 user_pref("toolkit.telemetry.enabled", false); // see [NOTE]
 //user_pref("toolkit.telemetry.server", "data:,");
 //user_pref("toolkit.telemetry.archive.enabled", false);
 //user_pref("toolkit.telemetry.newProfilePing.enabled", false); // [FF55+]
 //user_pref("toolkit.telemetry.shutdownPingSender.enabled", false); // [FF55+]
 //user_pref("toolkit.telemetry.updatePing.enabled", false); // [FF56+]
 //user_pref("toolkit.telemetry.bhrPing.enabled", false); // [FF57+] Background Hang Reporter
 //user_pref("toolkit.telemetry.firstShutdownPing.enabled", false); // [FF57+]

 /* 0333: disable Telemetry Coverage
  * [1] https://blog.mozilla.org/data/2018/08/20/effectively-measuring-search-in-firefox/ ***/
 //user_pref("toolkit.telemetry.coverage.opt-out", true); // [HIDDEN PREF]
 //user_pref("toolkit.coverage.opt-out", true); // [FF64+] [HIDDEN PREF]
 //user_pref("toolkit.coverage.endpoint.base", "");

 /* 0334: disable PingCentre telemetry (used in several System Add-ons) [FF57+]
  * Defense-in-depth: currently covered by 0331 ***/
 //user_pref("browser.ping-centre.telemetry", false);

 /* 0335: disable Firefox Home (Activity Stream) telemetry ***/
 //user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
 //user_pref("browser.newtabpage.activity-stream.telemetry", false);


/*
####################################################################################################################
[SECTION xxxx]: DISABLE WEBRTC (Web Real-Time Communication)                                                       #
####################################################################################################################
*/

user_pref("media.peerconnection.enabled", false);     // personal

// Block websites from tracking the microphone and camera status of your device
 user_pref("media.navigator.enabled", false);          // personal



/*
####################################################################################################################
[SECTION xxxx]: DISABLE WebAssembly                                                                                #
####################################################################################################################
*/


/* 5506: disable WebAssembly [FF52+]
 * Vulnerabilities [1] have increasingly been found, including those known and fixed
 * in native programs years ago [2]. WASM has powerful low-level access, making
 * certain attacks (brute-force) and vulnerabilities more possible
 * [STATS] ~0.2% of websites, about half of which are for crytopmining / malvertising [2][3]
 * [1] https://cve.mitre.org/cgi-bin/cvekey.cgi?keyword=wasm
 * [2] https://spectrum.ieee.org/tech-talk/telecom/security/more-worries-over-the-security-of-web-assembly
 * [3] https://www.zdnet.com/article/half-of-the-websites-using-webassembly-use-it-for-malicious-purposes ***/
user_pref("javascript.options.wasm", false);



/*
####################################################################################################################
[SECTION xxxx]: DISABLE JavaScript in pdfs                                                                         #
####################################################################################################################
*/

user_pref("pdfjs.enableScripting", false);

/*
####################################################################################################################
[SECTION xxxx]: NOTIFICATIONS                                                                                      #
####################################################################################################################
*/


/* 7018: disable Web Notifications
 * [WHY] Web Notifications are behind a prompt (7002)
 * [1] https://blog.mozilla.org/en/products/firefox/block-notification-requests/ ***/
   // user_pref("dom.webnotifications.enabled", false); // [FF22+]
   // user_pref("dom.webnotifications.serviceworker.enabled", false); // [FF44+]

/* 7019: disable Push Notifications [FF44+]
 * [WHY] Push requires subscription
 * [NOTE] To remove all subscriptions, reset "dom.push.userAgentID"
 * [1] https://support.mozilla.org/kb/push-notifications-firefox ***/
   // user_pref("dom.push.enabled", false);



/*
####################################################################################################################
[SECTION xxxx]: SPOOF YOUR BROWSER PLATFORM  (Need to diable the rfp=resist fingerprinting)                        #
####################################################################################################################


Say, you want to hide from websites the fact that you are using a Mac or a Windows (or some other) machine.
To do this you need to override the following properties of your browser:

    - User-Agent HTTP Header
    - Navigator WebAPI properties:
          Navigator.oscpu
          NavigatorID.platform
          NavigatorID.appVersion

The first is transmitted within an HTTP request and the rest three can be retrieved with a JavaScript.


EXAMPLE:
   general.useragent.override: Mozilla/5.0 (X11; Linux x86_64; rv:53.0) Gecko/20100101 Firefox/53.0
   general.oscpu.override: Linux x86_64
   general.platform.override: Linux x86_64
   general.appversion.override: 5.0 (Linux)


Other vhanges i've read about in the web:
    general.useragent.appName
    general.appname.override
    general.useragent.vendor
    general.useragent.vendorSub



default one (original one)
===========================
user_pref("general.useragent.override", "Mozilla/5.0 (X11; Linux x86_64; rv:105.0) Gecko/20100101 Firefox/105.0");


Useragent of the TOR browser
============================
user_pref("general.useragent.override", "Mozilla/5.0 (Windows NT 10.0; rv:68.0) Gecko/20100101 Firefox/68.0");
user_pref("general.platform.override", "Win32");


TO CHANGE THE USER AGENT TO CHROME IN WINDOWS
=============================================
uncomment the first 2 lines + set the preference "privacy.resistFingerprinting" to false

user_pref("general.useragent.override", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36");
user_pref("general.platform.override", "Win64");
user_pref("general.oscpu.override", "x64");
user_pref("general.appversion.override", "5.0 (Windows)");


NOTE:
THIS PREFERENCE WILL NOT WORK IF WE HAVE THE FOLLOWING PREFERENCE SET TO TRUE
    privacy.resistFingerprinting = true
*/


/*
####################################################################################################################
[SECTION xxxx]: UI CUSTOMIZATION                                                                                   #
####################################################################################################################
*/


//Remopve title bar
// user_pref("browser.tabs.inTitlebar", 2);     // default value
user_pref("browser.tabs.inTitlebar", 1);        // no title bar


//Compact mode
//menu button>More tools>Customize toolbar...>At the bottom of the panel, click Density>Choose Compact
//(not supported) from the menu options
user_pref("browser.compactmode.show", true);



/*
####################################################################################################################
[SECTION xxxx]: Set Firefox to look for userChrome.css and userContent.css at startup                              #
####################################################################################################################
*/

user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);


/*
####################################################################################################################
[SECTION xxxx]: DON'T TOUCH (Prefereneces set by default and shold not be changed)                                 #
####################################################################################################################
*/



/* 6001: enforce Firefox blocklist
 * [WHY] It includes updates for "revoked certificates"
 * [1] https://blog.mozilla.org/security/2015/03/03/revoking-intermediate-certificates-introducing-onecrl/ ***/
//user_pref("extensions.blocklist.enabled", true); // [DEFAULT: true]

/* 6002: enforce no referer spoofing
 * [WHY] Spoofing can affect CSRF (Cross-Site Request Forgery) protections ***/
//user_pref("network.http.referer.spoofSource", false); // [DEFAULT: false]

/* 6004: enforce a security delay on some confirmation dialogs such as install, open/save
 * [1] https://www.squarefree.com/2004/07/01/race-conditions-in-security-dialogs/ ***/
//user_pref("security.dialog_enable_delay", 1000); // [DEFAULT: 1000]

/* 6008: enforce no First Party Isolation [FF51+]
 * [WARNING] Replaced with network partitioning (FF85+) and TCP (2701),
 * and enabling FPI disables those. FPI is no longer maintained ***/
//user_pref("privacy.firstparty.isolate", false); // [DEFAULT: false]

/* 6009: enforce SmartBlock shims [FF81+]
 * In FF96+ these are listed in about:compat
 * [1] https://blog.mozilla.org/security/2021/03/23/introducing-smartblock/ ***/
//user_pref("extensions.webcompat.enable_shims", true); // [DEFAULT: true]

/* 6010: enforce/reset TLS 1.0/1.1 downgrades to session only
 * [NOTE] In FF97+ the TLS 1.0/1.1 downgrade UX was removed
 * [TEST] https://tls-v1-1.badssl.com:1010/ ***/
//user_pref("security.tls.version.enable-deprecated", false); // [DEFAULT: false]

/* 6011: enforce disabling of Web Compatibility Reporter [FF56+]
 * Web Compatibility Reporter adds a "Report Site Issue" button to send data to Mozilla
 * [WHY] To prevent wasting Mozilla's time with a custom setup ***/
//user_pref("extensions.webcompat-reporter.enabled", false); // [DEFAULT: false]



/*
####################################################################################################################
[SECTION xxxx]: ADDITIONAL                                                                                         #
####################################################################################################################
*/


/* 5002: disable memory cache
 * capacity: -1=determine dynamically (default), 0=none, n=memory capacity in kibibytes ***/
   // user_pref("browser.cache.memory.enable", false);
   // user_pref("browser.cache.memory.capacity", 0);

/* 5004: disable permissions manager from writing to disk [FF41+] [RESTART]
 * [NOTE] This means any permission changes are session only
 * [1] https://bugzilla.mozilla.org/967812 ***/
   // user_pref("permissions.memory_only", true); // [HIDDEN PREF]

/* 5005: disable intermediate certificate caching [FF41+] [RESTART]
 * [NOTE] This affects login/cert/key dbs. The effect is all credentials are session-only.
 * Saved logins and passwords are not available. Reset the pref and restart to return them ***/
   // user_pref("security.nocertdb", true); // [HIDDEN PREF in FF101 or lower]

/* 5006: disable favicons in history and bookmarks
 * [NOTE] Stored as data blobs in favicons.sqlite, these don't reveal anything that your
 * actual history (and bookmarks) already do. Your history is more detailed, so
 * control that instead; e.g. disable history, clear history on exit, use PB mode
 * [NOTE] favicons.sqlite is sanitized on Firefox close ***/
   // user_pref("browser.chrome.site_icons", false);

/* 5008: disable resuming session from crash
 * [TEST] about:crashparent ***/
   // user_pref("browser.sessionstore.resume_from_crash", false);

/* 5009: disable "open with" in download dialog [FF50+]
 * Application data isolation [1]
 * [1] https://bugzilla.mozilla.org/1281959 ***/
   // user_pref("browser.download.forbid_open_with", true);


/* 5011: disable location bar dropdown
 * This value controls the total number of entries to appear in the location bar dropdown ***/
   // user_pref("browser.urlbar.maxRichResults", 0);

/* 5012: disable location bar autofill
 * [1] https://support.mozilla.org/kb/address-bar-autocomplete-firefox#w_url-autocomplete ***/
   // user_pref("browser.urlbar.autoFill", false);


/* 5016: discourage downloading to desktop
 * 0=desktop, 1=downloads (default), 2=last used
 * [SETTING] To set your default "downloads": General>Downloads>Save files to ***/
   // user_pref("browser.download.folderList", 2)




/*
####################################################################################################################
[SECTION xxxx]: DEPRECATED / REMOVED / LEGACY / RENAMED                                                            #
####################################################################################################################
*/



// 2801: delete cookies and site data on exit - replaced by sanitizeOnShutdown* (2810)
// 0=keep until they expire (default), 2=keep until you close Firefox
// [SETTING] Privacy & Security>Cookies and Site Data>Delete cookies and site data when Firefox is closed
// [-] https://bugzilla.mozilla.org/buglist.cgi?bug_id=1681493,1681495,1681498,1759665,1764761
//user_pref("network.cookie.lifetimePolicy", 2);
