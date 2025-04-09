===============================================================================
https_settings — Apache Server Configuration Tool for Windows
===============================================================================

The UI, README, LICENSE, CHANGELOG, and internal logic were written with the
assistance of ChatGPT by OpenAI, used as a coding and writing assistant.

VERSION: 1.0.1
DATE: 2025-04-09

-------------------------------------------------------------------------------
WHAT IS THIS?
-------------------------------------------------------------------------------

This application helps you configure your local Apache HTTP Server (httpd) installation on Windows.
It provides a friendly interface to define common settings such as:

- Server Location (path to Apache folder)
- SRVROOT path
- HTTP and HTTPS ports
- Virtual Hosts and Aliases

The tool modifies the relevant Apache configuration files:
- httpd.conf
- httpd-vhosts.conf

-------------------------------------------------------------------------------
HOW TO USE
-------------------------------------------------------------------------------

1. Extract Apache (e.g., "httpd-2.4.62-240904-win64-VS17.zip") to a local folder.
2. Launch this application: "https_settings.exe".
3. Add your Apache folder using the "Servers" section.
4. Use the "Configurations" and "Parameters" sections to define your desired setup.
5. Save your changes. The app will update the relevant config files.

To verify your setup:
- You can manually run "httpd.exe" and check for startup errors.
- You may also use "localhost" in your browser to verify the configured sites.

-------------------------------------------------------------------------------
REQUIREMENTS
-------------------------------------------------------------------------------

- Windows 10 or later
- Apache HTTP Server installed locally (not bundled with this app)

-------------------------------------------------------------------------------
FILES AND FOLDERS
-------------------------------------------------------------------------------

This ZIP contains:
- https_settings.exe ............ the application
- README.txt .................... this file
- LICENSE.txt ................... license information
- CHANGELOG.txt ................. version history
- httpd_settings_data/ .......... data folder created automatically at runtime

Note: The app does **not** modify any Apache binaries or start/stop services.

-------------------------------------------------------------------------------
TIPS & TROUBLESHOOTING
-------------------------------------------------------------------------------

- If Apache doesn't start, check "httpd.conf" manually or run "httpd.exe" in CMD.
- Make sure ports you define are not already in use by another program.
- Use unique port numbers and test with different browsers or tools like "curl".

-------------------------------------------------------------------------------
SUPPORT
-------------------------------------------------------------------------------

For help or updates, please visit:
https://github.com/iuscl-ide/httpd_settings

-------------------------------------------------------------------------------
LICENSE
-------------------------------------------------------------------------------

This software is distributed under the MIT License. See LICENSE.txt for details.

===============================================================================
