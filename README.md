# Asset Self Reporting SnipeIT
A script to compile an assets information and update SnipeIT inventory system.

This is a script I use in my environment to automatically update all domain assets daily to my SnipeIT Inventory System and manage certain aspects of the assets based on information the script finds in the inventory system.

Sensitive information and some functions have been removed which may cause some errors in a few functions. You will need to modify this for you environment.

## Recent Updates

### Secure Boot and BIOS Information Collection
The script now collects Secure Boot status, certificate expiry information, and BIOS release dates to help identify systems affected by the [Microsoft Secure Boot certificate expiration issue](https://support.microsoft.com/en-us/topic/windows-secure-boot-certificate-expiration-and-ca-updates-7ff40d33-95dc-4c3c-8725-a9b95457578e).

**New Information Collected:**
- **Secure Boot Status** - Whether Secure Boot is enabled, disabled, or not supported
- **Secure Boot Certificate Expiry** - Expiration dates of certificates with status indicators (EXPIRED, EXPIRING SOON, Valid)
- **BIOS Release Date** - When the current BIOS firmware was released

See [SECURE_BOOT_SETUP.md](SECURE_BOOT_SETUP.md) for detailed setup instructions and required Snipe-IT custom fields.

# Customization

Place config.ps1 in the same directory as this script, with the following parameters completed.

$snipeiturl = "https://your.snipeit.url"
$snipeitapi = "your.snipeit.apikey"