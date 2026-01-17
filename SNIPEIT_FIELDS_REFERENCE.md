# Quick Reference: Snipe-IT Custom Fields

## Required Custom Fields for Secure Boot and BIOS Information

Add these three custom fields to your Snipe-IT instance to support the new Secure Boot and BIOS data collection:

### Field 41: Secure Boot Status
```
Field Name: Secure Boot Status
DB Field: _snipeit_secure_boot_status_41
Field Type: Text
Format: Single Line Text
Help Text: Current Secure Boot status (Enabled/Disabled/Not Supported)
Required: No
```

**Example Values:**
- `Enabled`
- `Disabled`
- `Not Supported (Legacy BIOS)`
- `Unknown`

---

### Field 42: Secure Boot Certificate Expiry
```
Field Name: Secure Boot Certificate Expiry
DB Field: _snipeit_secure_boot_cert_expiry_42
Field Type: Textarea
Format: Multi-line Text
Help Text: Secure Boot certificate expiration dates with status indicators
Required: No
```

**Example Value:**
```
Microsoft Corporation UEFI CA 2011 : 2026-06-30 (EXPIRING SOON, 165 days)
Microsoft Windows Production PCA 2011 : 2026-10-30 (Valid, 287 days)
```

**Status Indicators:**
- `EXPIRED` - Certificate has expired
- `EXPIRING SOON` - Less than 180 days until expiry
- `Valid` - More than 180 days until expiry

---

### Field 43: BIOS Release Date
```
Field Name: BIOS Release Date
DB Field: _snipeit_bios_release_date_43
Field Type: Text (or Date if you prefer)
Format: YYYY-MM-DD
Help Text: Date when the BIOS firmware was released
Required: No
```

**Example Value:**
- `2023-05-15`

---

## How to Add These Fields in Snipe-IT

1. Log in as administrator
2. Go to **Settings** → **Custom Fields**
3. Click **Create New**
4. Fill in the details from above
5. Save each field
6. Add all three fields to your asset fieldset
7. Associate fieldset with your asset models

## Important Notes

- The field numbers (41, 42, 43) are used in the script to map data to Snipe-IT
- If your Snipe-IT instance uses different field numbers, update the script accordingly
- Certificate information requires administrator privileges to collect
- Legacy BIOS systems will show "Not Supported" for Secure Boot status
- Empty BIOS release dates indicate the BIOS doesn't report this information

## Verifying the Setup

After creating the fields and deploying the updated script:

1. Run the script on a test machine
2. Check the asset in Snipe-IT
3. Verify all three fields are populated with data
4. Review logs for any warnings about expiring certificates

## Support

For detailed setup instructions, see [SECURE_BOOT_SETUP.md](SECURE_BOOT_SETUP.md)
