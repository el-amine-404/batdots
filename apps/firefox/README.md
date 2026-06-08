# Firefox settings

```txt
    _____           ____
   / __(_)_______  / __/___  _  __
  / /_/ / ___/ _ \/ /_/ __ \| |/_/
 / __/ / /  /  __/ __/ /_/ />  <
/_/ /_/_/   \___/_/  \____/_/|_|

```

This dotfiles represent my personal settings for firefox, I used 2 files:

| FILE             | PATH                                                            | USED FOR   |
| ---------------- | --------------------------------------------------------------- | ---------- |
| `user.js`        | `$HOME/.mozilla/firefox/xxxx.profileName/user.js`               | Settings   |
| `userChrome.css` | `$HOME/.mozilla/firefox/xxxx.profileName/chrome/userChrome.css` | Appearence |

Note:

- Instead of using the profiles created by firefox i created i custom directory
  to hold the settings of firefox

```sh
$HOME/.mozilla/firefox/custom-profile

```

use the firefox's profile manager and then create a new profile but choose the
folder to the one created.

Another option is to start firefox by using the command line switches to open
the profile

```bash
firefox [OPTIONS]

  -P <profile>       Start with <profile>
  --profile <path>   Start with profile at <path>
  --ProfileManager   Start with ProfileManager

```

## 1. Firefox's settings/preferences

Prefs are settings that control Firefox's behavior. there is 3 ways to specify
the prefs:

- Some but not all can be set from ☰ `Settings`
- all can be found in `about:config`, except for what are called
  `hidden preferences` which will only show when they are modified (i.e. set to
  any value by the user or browser - they have a trash can symbol for resetting)
- A `user.js` file which is a javascript file and is text based, and resides in
  your profile folder. It is used to set preferences for that profile when
  Firefox starts. You can update the user.js while Firefox is open, it is only
  ever read when Firefox starts.

Note:

- There is a 3rd file called `pref.js` that represents the default config. This
  file should never be edited manually because it is overrrided by the `user.js`
  (This way if you want to reset the settings you only have to delete the
  `user.js`)

For more informaions:

- <a href="https://github.com/arkenfox/user.js/wiki/2.1-User.js" title="https://github.com/arkenfox/user.js/wiki/2.1-User.js">https://github.com/arkenfox/user.js/wiki/2.1-User.js</a>
- <a href="https://github.com/arkenfox/user.js" title="https://github.com/arkenfox/user.js">https://github.com/arkenfox/user.js</a>

## 2. Firefox's appearence

- The Firefox UI is - in a way - like a Web page.
  - It is defined by a series of stylistic rules in a Web-based language called
    CSS.
  - You can override the default rules by creating your own.
  - This is done by adding a new file to your Firefox profile.
  - Inside the file, you create (add) new rules that will affect existing visual
    elements in the Firefox UI.

- To modify the way in which Web pages and e-mails are displayed, you should
  edit the `userContent.css` file.
- To modify the appearance of the application itself, you should edit the
  `userChrome.css` file.

NOTE:

- Keep in mind CSS code can not create entirely new items, buttons or toolbars.
- it only can modify already present ui items.
- To make startup faster for most users, Firefox 69 will no longer look for this
  file `userChrome.css` automatically. You need to tell it to look. Make sure
  the following line exists in the user.js:

  ```js
  user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
  ```

EXAMPLES OF THE userChrome.css FILE

- [https://github.com/topics/userchrome](https://github.com/topics/userchrome "https://github.com/topics/userchrome")
- [https://github.com/topics/firefox-css](https://github.com/topics/firefox-css "https://github.com/topics/firefox-css")
- [https://github.com/andreasgrafen/cascade](https://github.com/andreasgrafen/cascade "https://github.com/andreasgrafen/cascade")
- [https://github.com/migueravila/SimpleFox](https://github.com/migueravila/SimpleFox "https://github.com/migueravila/SimpleFox")
- [https://support.mozilla.org/en-US/kb/contributors-guide-firefox-advanced-customization](https://support.mozilla.org/en-US/kb/contributors-guide-firefox-advanced-customization "https://support.mozilla.org/en-US/kb/contributors-guide-firefox-advanced-customization")

## 3. Firefox's policies

I have not yet discovered this part of firefox settings (and it is not included
in my dotfiles)

Policy support can be implemented using a JSON file called `policies.json`

Unlike controlling Firefox with using Group Policy, the policies.json is
cross-platform compatible, making it preferred method for enterprise
environments that have workstations running various operating systems.

To implement this policy support, a policies.json file needs to be created. This
file goes into a directory called distribution within the Firefox installation
directory.

This directory is not usually included by default, so you may need to manually
create this directory. Under linux the policies.json file is located in:
`/lib/firefox/distribution/policies.json`

NOTE:

- To see what policies you have active on a computer, type in "about:policies"
  in the address bar. This will show:
  - The list of applied policies, including the policy name and value. (if no
    policy is set the list will be empty)
  - Documentation section that includes all available policies.

- [https://github.com/mozilla/policy-templates/blob/master/README.md](https://github.com/mozilla/policy-templates/blob/master/README.md "https://github.com/mozilla/policy-templates/blob/master/README.md")
