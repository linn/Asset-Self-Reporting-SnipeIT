# Secure Boot and BIOS Information Collection

## Overview

This update adds collection of Secure Boot status, certificate expiry information, and BIOS release dates to help identify systems that may be affected by the Microsoft Secure Boot certificate expiration issue.

## Background

Microsoft has announced that Secure Boot certificates are expiring in June 2026, which may prevent affected systems from booting. This enhancement helps identify which systems need attention.

**References:**
- [Microsoft Support Article](https://support.microsoft.com/en-us/topic/windows-secure-boot-certificate-expiration-and-ca-updates-7ff40d33-95dc-4c3c-8725-a9b95457578e)
- [Reddit Discussion](https://www.reddit.com/r/sysadmin/comments/1qeumgz/secure_boot_certificates_expiring_june_resolution/)

## Information Collected

The script now collects three additional pieces of information:

### 1. Secure Boot Status
- **Field Name:** `SecureBootStatus`
- **Possible Values:**
  - `Enabled` - Secure Boot is currently enabled
  - `Disabled` - Secure Boot is supported but disabled
  - `Not Supported (Legacy BIOS)` - System is using Legacy BIOS (not UEFI)
  - `Unknown` - Unable to determine status

### 2. Secure Boot Certificate Expiry
- **Field Name:** `SecureBootCertExpiry`
- **Format:** Multi-line text with certificate information
- **Example:**
  ```
  Microsoft Corporation UEFI CA 2011 : 2026-06-30 (EXPIRING SOON, 165 days)
  Microsoft Windows Production PCA 2011 : 2026-10-30 (Valid, 287 days)
  ```
- **Status Indicators:**
  - `EXPIRED` - Certificate has already expired
  - `EXPIRING SOON` - Certificate expires within 180 days
  - `Valid` - Certificate is valid for more than 180 days
- **Note:** Requires administrator privileges to extract certificate information

### 3. BIOS Release Date
- **Field Name:** `BiosReleaseDate`
- **Format:** `yyyy-MM-dd` (e.g., `2023-05-15`)
- **Purpose:** Helps determine if BIOS is up-to-date with latest security patches

## Snipe-IT Custom Fields Setup

To use these new fields, you must create the following custom fields in your Snipe-IT instance:

### Field 41: Secure Boot Status
- **Field Name:** `Secure Boot Status`
- **DB Field:** `_snipeit_secure_boot_status_41`
- **Field Type:** Text
- **Format:** Single Line
- **Help Text:** Current Secure Boot status (Enabled/Disabled/Not Supported)

### Field 42: Secure Boot Certificate Expiry
- **Field Name:** `Secure Boot Certificate Expiry`
- **DB Field:** `_snipeit_secure_boot_cert_expiry_42`
- **Field Type:** Textarea
- **Format:** Multi-line text
- **Help Text:** Secure Boot certificate expiration information with status indicators

### Field 43: BIOS Release Date
- **Field Name:** `BIOS Release Date`
- **DB Field:** `_snipeit_bios_release_date_43`
- **Field Type:** Text or Date
- **Format:** `YYYY-MM-DD`
- **Help Text:** Date when the BIOS firmware was released

## How to Create Custom Fields in Snipe-IT

1. Log in to Snipe-IT as an administrator
2. Navigate to **Settings** → **Custom Fields**
3. Click **Create New** for each field
4. Fill in the details as specified above
5. Ensure the field numbers (41, 42, 43) match if you're using sequential numbering
6. Add these fields to your asset fieldset
7. Associate the fieldset with your asset models

## Identifying Affected Systems

After the script runs and collects this information, you can:

1. **Check Secure Boot Status:** Filter for systems with `Enabled` or `Disabled` status
2. **Review Certificate Expiry:** Look for certificates marked as `EXPIRING SOON` or `EXPIRED`
3. **Verify BIOS Age:** Compare BIOS release dates to manufacturer's latest available versions
4. **Priority Systems:** Focus on systems with:
   - Secure Boot enabled
   - Certificates expiring in 2026 (especially before June)
   - Older BIOS versions that may need updates

## Script Behavior

- The script automatically logs warnings for systems with certificates expiring in early 2026
- Certificate parsing requires administrator privileges; if unavailable, the field will show "Unable to read certificates (requires admin privileges)"
- Legacy BIOS systems will show "Not Supported" and have empty certificate information
- The script safely handles errors and continues even if Secure Boot information cannot be collected

## Troubleshooting

### Certificate Information Shows "Unable to read certificates"
- **Cause:** Script is not running with administrator privileges
- **Solution:** Ensure the script runs as SYSTEM or with elevated privileges

### Secure Boot Status Shows "Not Supported (Legacy BIOS)"
- **Cause:** System is using Legacy BIOS instead of UEFI
- **Action:** These systems are not affected by the Secure Boot certificate issue

### BIOS Release Date is Empty
- **Cause:** BIOS doesn't report a release date in WMI
- **Action:** Manually check BIOS version with manufacturer's website

## Testing

To test the implementation without affecting production:

1. Run the script manually on a test system
2. Check the generated CSV record file for the new fields
3. Verify the information appears correctly in Snipe-IT
4. Review logs for any warnings or errors related to certificate expiry

## Next Steps

1. Create the three custom fields in Snipe-IT
2. Deploy the updated script to your client systems
3. Wait for systems to report in
4. Generate reports to identify affected systems
5. Plan BIOS updates for systems with expiring certificates
6. Monitor and track remediation progress

## Additional Notes

- The BIOS version field (existing field `_snipeit_bios_11`) continues to work as before
- Certificate expiry information is checked against all certificates in the Secure Boot database (db)
- The script focuses on the db (authorized signature database) as it contains the certificates used to verify bootloaders
- Systems may have multiple certificates; all are reported with their expiry dates
